// G7 Primary authentication needs P-256 point addition, subtraction and scalar operations that
// CryptoKit does not expose. micro-ecc is therefore compiled inside this one translation unit with
// its low-level VLI API enabled and every unused curve disabled. Including the implementation here
// is deliberate. Adding `uECC.c` separately to the Xcode Compile Sources phase would compile the
// same symbols twice and would lose these configuration flags.
//
// Vendored source: https://github.com/kmackay/micro-ecc
// Pinned revision: 541b3a78026420a3e369c4c9281c396b5e531113
#define uECC_ENABLE_VLI_API 1
#define uECC_SUPPORTS_secp160r1 0
#define uECC_SUPPORTS_secp192r1 0
#define uECC_SUPPORTS_secp224r1 0
#define uECC_SUPPORTS_secp256r1 1
#define uECC_SUPPORTS_secp256k1 0
#define uECC_SUPPORT_COMPRESSED_POINT 0

#include "DexcomG7ECC.h"

#include "../../../../ThirdParty/micro-ecc/uECC.h"
#include "../../../../ThirdParty/micro-ecc/uECC_vli.h"
#include "../../../../ThirdParty/micro-ecc/uECC.c"

#include <string.h>
#include <stdlib.h>

static int DexcomG7ECCRNG(uint8_t *dest, unsigned size) {
    // micro-ecc requests random bytes through this callback. `arc4random_buf` is backed by the
    // system cryptographic random source and fills the exact buffer supplied by the library.
    arc4random_buf(dest, size);
    return 1;
}

static uECC_Curve DexcomG7ECCCurve(void) {
    // Resolve the one enabled curve lazily and install the random callback before any key or scalar
    // generation can occur. The static pointer is immutable after this first setup.
    static uECC_Curve curve = 0;
    if (!curve) {
        uECC_set_rng(DexcomG7ECCRNG);
        curve = uECC_secp256r1();
    }
    return curve;
}

static unsigned DexcomG7ECCNumWords(void) {
    return uECC_curve_num_words(DexcomG7ECCCurve());
}

static const uint8_t DexcomG7ECCGeneratorPoint[DexcomG7ECCPointSize] = {
    0x6b, 0x17, 0xd1, 0xf2, 0xe1, 0x2c, 0x42, 0x47,
    0xf8, 0xbc, 0xe6, 0xe5, 0x63, 0xa4, 0x40, 0xf2,
    0x77, 0x03, 0x7d, 0x81, 0x2d, 0xeb, 0x33, 0xa0,
    0xf4, 0xa1, 0x39, 0x45, 0xd8, 0x98, 0xc2, 0x96,
    0x4f, 0xe3, 0x42, 0xe2, 0xfe, 0x1a, 0x7f, 0x9b,
    0x8e, 0xe7, 0xeb, 0x4a, 0x7c, 0x0f, 0x9e, 0x16,
    0x2b, 0xce, 0x33, 0x57, 0x6b, 0x31, 0x5e, 0xce,
    0xcb, 0xb6, 0x40, 0x68, 0x37, 0xbf, 0x51, 0xf5
};

// micro-ecc stores its internal words in the platform's native order while every bridge function
// accepts the standard 32-byte big-endian scalar and 64-byte uncompressed point coordinates.
static void DexcomG7ECCPointBytesToNative(uECC_word_t *pointWords,
                                          const uint8_t point[DexcomG7ECCPointSize]) {
    const unsigned numWords = DexcomG7ECCNumWords();
    uECC_vli_bytesToNative(pointWords, point, DexcomG7ECCScalarSize);
    uECC_vli_bytesToNative(pointWords + numWords, point + DexcomG7ECCScalarSize, DexcomG7ECCScalarSize);
}

static void DexcomG7ECCPointNativeToBytes(uint8_t point[DexcomG7ECCPointSize],
                                          const uECC_word_t *pointWords) {
    const unsigned numWords = DexcomG7ECCNumWords();
    uECC_vli_nativeToBytes(point, DexcomG7ECCScalarSize, pointWords);
    uECC_vli_nativeToBytes(point + DexcomG7ECCScalarSize, DexcomG7ECCScalarSize, pointWords + numWords);
}

static void DexcomG7ECCScalarBytesToNative(uECC_word_t *scalarWords,
                                           const uint8_t scalar[DexcomG7ECCScalarSize]) {
    uECC_vli_bytesToNative(scalarWords, scalar, DexcomG7ECCScalarSize);
}

static void DexcomG7ECCScalarNativeToBytes(uint8_t scalar[DexcomG7ECCScalarSize],
                                           const uECC_word_t *scalarWords) {
    uECC_vli_nativeToBytes(scalar, DexcomG7ECCScalarSize, scalarWords);
}

static void DexcomG7ECCSetSmall(uECC_word_t *target, unsigned value) {
    const unsigned numWords = DexcomG7ECCNumWords();
    memset(target, 0, sizeof(uECC_word_t) * numWords);
    target[0] = (uECC_word_t)value;
}

static void DexcomG7ECCNegateY(const uECC_word_t *point, uECC_word_t *result) {
    const unsigned numWords = DexcomG7ECCNumWords();
    const uECC_word_t *mod = uECC_curve_p(DexcomG7ECCCurve());

    // An affine P-256 point is negated by keeping X and replacing Y with `p - Y`. The special zero
    // value remains zero so the result stays in the expected internal representation.
    uECC_vli_set(result, point, numWords);
    if (uECC_vli_isZero(point + numWords, numWords)) {
        uECC_vli_clear(result + numWords, numWords);
        return;
    }

    uECC_vli_modSub(result + numWords, mod, point + numWords, mod, numWords);
}

static bool DexcomG7ECCPointDoubleInternal(const uECC_word_t *point, uECC_word_t *result) {
    const unsigned numWords = DexcomG7ECCNumWords();
    const uECC_word_t *mod = uECC_curve_p(DexcomG7ECCCurve());
    uECC_word_t x[numWords];
    uECC_word_t y[numWords];
    uECC_word_t numerator[numWords];
    uECC_word_t denominator[numWords];
    uECC_word_t inverse[numWords];
    uECC_word_t lambda[numWords];
    uECC_word_t tmp[numWords];
    uECC_word_t three[numWords];
    uECC_word_t two[numWords];

    // Doubling a point with Y equal to zero produces the point at infinity, which this wrapper
    // reports as a failed finite-point operation.
    if (uECC_vli_isZero(point + numWords, numWords)) {
        return false;
    }

    uECC_vli_set(x, point, numWords);
    uECC_vli_set(y, point + numWords, numWords);
    DexcomG7ECCSetSmall(three, 3);
    DexcomG7ECCSetSmall(two, 2);

    // Calculate the affine tangent slope for secp256r1 where the curve parameter `a` is minus 3.
    uECC_vli_modSquare_fast(numerator, x, DexcomG7ECCCurve());
    uECC_vli_modMult(numerator, numerator, three, mod, numWords);
    uECC_vli_modSub(numerator, numerator, three, mod, numWords); /* a = -3 for secp256r1 */

    uECC_vli_modMult(denominator, y, two, mod, numWords);
    if (uECC_vli_isZero(denominator, numWords)) {
        return false;
    }

    uECC_vli_modInv(inverse, denominator, mod, numWords);
    uECC_vli_modMult(lambda, numerator, inverse, mod, numWords);

    // Apply the standard affine formulas to recover the doubled X and Y coordinates.
    uECC_vli_modSquare_fast(result, lambda, DexcomG7ECCCurve());
    uECC_vli_modMult(tmp, x, two, mod, numWords);
    uECC_vli_modSub(result, result, tmp, mod, numWords);

    uECC_vli_modSub(tmp, x, result, mod, numWords);
    uECC_vli_modMult(result + numWords, lambda, tmp, mod, numWords);
    uECC_vli_modSub(result + numWords, result + numWords, y, mod, numWords);
    return true;
}

// micro-ecc exposes point multiplication but not general affine point addition. J-PAKE requires
// both operations, so the bridge implements the standard P-256 affine formulas using micro-ecc's
// tested modular arithmetic. The point at infinity is reported as `false` to the caller.
static bool DexcomG7ECCPointAddInternal(const uECC_word_t *left,
                                        const uECC_word_t *right,
                                        uECC_word_t *result) {
    const unsigned numWords = DexcomG7ECCNumWords();
    const uECC_word_t *mod = uECC_curve_p(DexcomG7ECCCurve());
    uECC_word_t dx[numWords];
    uECC_word_t dy[numWords];
    uECC_word_t inverse[numWords];
    uECC_word_t lambda[numWords];
    uECC_word_t tmp[numWords];
    uECC_word_t negated[numWords * 2];

    if (uECC_vli_equal(left, right, numWords) &&
        uECC_vli_equal(left + numWords, right + numWords, numWords)) {
        return DexcomG7ECCPointDoubleInternal(left, result);
    }

    DexcomG7ECCNegateY(right, negated);
    if (uECC_vli_equal(left, negated, numWords) &&
        uECC_vli_equal(left + numWords, negated + numWords, numWords)) {
        return false;
    }

    uECC_vli_modSub(dx, right, left, mod, numWords);
    if (uECC_vli_isZero(dx, numWords)) {
        return false;
    }
    uECC_vli_modSub(dy, right + numWords, left + numWords, mod, numWords);

    uECC_vli_modInv(inverse, dx, mod, numWords);
    uECC_vli_modMult(lambda, dy, inverse, mod, numWords);

    uECC_vli_modSquare_fast(result, lambda, DexcomG7ECCCurve());
    uECC_vli_modSub(result, result, left, mod, numWords);
    uECC_vli_modSub(result, result, right, mod, numWords);

    uECC_vli_modSub(tmp, left, result, mod, numWords);
    uECC_vli_modMult(result + numWords, lambda, tmp, mod, numWords);
    uECC_vli_modSub(result + numWords, result + numWords, left + numWords, mod, numWords);
    return true;
}

bool DexcomG7ECCGenerateKeyPair(uint8_t publicKey[DexcomG7ECCPointSize],
                                uint8_t privateKey[DexcomG7ECCScalarSize]) {
    return uECC_make_key(publicKey, privateKey, DexcomG7ECCCurve()) == 1;
}

bool DexcomG7ECCIsValidPoint(const uint8_t point[DexcomG7ECCPointSize]) {
    return uECC_valid_public_key(point, DexcomG7ECCCurve()) == 1;
}

bool DexcomG7ECCPointAdd(const uint8_t left[DexcomG7ECCPointSize],
                         const uint8_t right[DexcomG7ECCPointSize],
                         uint8_t result[DexcomG7ECCPointSize]) {
    const unsigned numWords = DexcomG7ECCNumWords();
    uECC_word_t leftWords[numWords * 2];
    uECC_word_t rightWords[numWords * 2];
    uECC_word_t resultWords[numWords * 2];

    DexcomG7ECCPointBytesToNative(leftWords, left);
    DexcomG7ECCPointBytesToNative(rightWords, right);

    if (!DexcomG7ECCPointAddInternal(leftWords, rightWords, resultWords)) {
        return false;
    }

    DexcomG7ECCPointNativeToBytes(result, resultWords);
    return true;
}

bool DexcomG7ECCPointSubtract(const uint8_t left[DexcomG7ECCPointSize],
                              const uint8_t right[DexcomG7ECCPointSize],
                              uint8_t result[DexcomG7ECCPointSize]) {
    const unsigned numWords = DexcomG7ECCNumWords();
    uECC_word_t rightWords[numWords * 2];
    uECC_word_t negatedRight[numWords * 2];
    uint8_t negatedRightBytes[DexcomG7ECCPointSize];

    DexcomG7ECCPointBytesToNative(rightWords, right);
    DexcomG7ECCNegateY(rightWords, negatedRight);
    DexcomG7ECCPointNativeToBytes(negatedRightBytes, negatedRight);
    return DexcomG7ECCPointAdd(left, negatedRightBytes, result);
}

bool DexcomG7ECCPointMultiply(const uint8_t point[DexcomG7ECCPointSize],
                              const uint8_t scalar[DexcomG7ECCScalarSize],
                              uint8_t result[DexcomG7ECCPointSize]) {
    const unsigned numWords = DexcomG7ECCNumWords();
    const unsigned numNWords = uECC_curve_num_n_words(DexcomG7ECCCurve());
    uECC_word_t pointWords[numWords * 2];
    uECC_word_t scalarWords[numNWords];
    uECC_word_t resultWords[numWords * 2];

    // Convert both inputs into micro-ecc's native word order, perform the multiplication, then
    // restore the big-endian wire representation expected by the Objective-C bridge.
    DexcomG7ECCPointBytesToNative(pointWords, point);
    DexcomG7ECCScalarBytesToNative(scalarWords, scalar);
    uECC_point_mult(resultWords, pointWords, scalarWords, DexcomG7ECCCurve());
    DexcomG7ECCPointNativeToBytes(result, resultWords);
    return true;
}

bool DexcomG7ECCGeneratorMultiply(const uint8_t scalar[DexcomG7ECCScalarSize],
                                  uint8_t result[DexcomG7ECCPointSize]) {
    static const uint8_t oneScalar[DexcomG7ECCScalarSize] = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
    };

    // micro-ecc's internal multiplier rejects some identity shortcuts. Return the published
    // generator directly for scalar one, then use the common arbitrary-point path for all others.
    if (memcmp(scalar, oneScalar, sizeof(oneScalar)) == 0) {
        memcpy(result, DexcomG7ECCGeneratorPoint, DexcomG7ECCPointSize);
        return true;
    }

    return DexcomG7ECCPointMultiply(DexcomG7ECCGeneratorPoint, scalar, result);
}

bool DexcomG7ECCScalarRandom(uint8_t scalar[DexcomG7ECCScalarSize]) {
    const unsigned numNWords = uECC_curve_num_n_words(DexcomG7ECCCurve());
    uECC_word_t scalarWords[numNWords];
    // Request a non-zero integer below the group order rather than reducing unrestricted random
    // bytes, which avoids bias and invalid zero scalars.
    if (!uECC_generate_random_int(scalarWords, uECC_curve_n(DexcomG7ECCCurve()), numNWords)) {
        return false;
    }
    DexcomG7ECCScalarNativeToBytes(scalar, scalarWords);
    return true;
}

bool DexcomG7ECCScalarMultiplyModN(const uint8_t left[DexcomG7ECCScalarSize],
                                   const uint8_t right[DexcomG7ECCScalarSize],
                                   uint8_t result[DexcomG7ECCScalarSize]) {
    const unsigned numNWords = uECC_curve_num_n_words(DexcomG7ECCCurve());
    uECC_word_t leftWords[numNWords];
    uECC_word_t rightWords[numNWords];
    uECC_word_t resultWords[numNWords];

    DexcomG7ECCScalarBytesToNative(leftWords, left);
    DexcomG7ECCScalarBytesToNative(rightWords, right);
    uECC_vli_modMult(resultWords, leftWords, rightWords, uECC_curve_n(DexcomG7ECCCurve()), numNWords);
    DexcomG7ECCScalarNativeToBytes(result, resultWords);
    return true;
}

bool DexcomG7ECCScalarSubtractModN(const uint8_t left[DexcomG7ECCScalarSize],
                                   const uint8_t right[DexcomG7ECCScalarSize],
                                   uint8_t result[DexcomG7ECCScalarSize]) {
    const unsigned numNWords = uECC_curve_num_n_words(DexcomG7ECCCurve());
    uECC_word_t leftWords[numNWords];
    uECC_word_t rightWords[numNWords];
    uECC_word_t resultWords[numNWords];

    DexcomG7ECCScalarBytesToNative(leftWords, left);
    DexcomG7ECCScalarBytesToNative(rightWords, right);
    uECC_vli_modSub(resultWords, leftWords, rightWords, uECC_curve_n(DexcomG7ECCCurve()), numNWords);
    DexcomG7ECCScalarNativeToBytes(result, resultWords);
    return true;
}

void DexcomG7ECCScalarReduceModN(const uint8_t scalar[DexcomG7ECCScalarSize],
                                 uint8_t result[DexcomG7ECCScalarSize]) {
    const unsigned numNWords = uECC_curve_num_n_words(DexcomG7ECCCurve());
    uECC_word_t scalarWords[numNWords];
    uECC_word_t reducedWords[numNWords];

    DexcomG7ECCScalarBytesToNative(scalarWords, scalar);
    uECC_vli_set(reducedWords, scalarWords, numNWords);
    // The input has the same bit width as the group order, so at most one subtraction is required
    // to produce the canonical value below `n`.
    if (uECC_vli_cmp(reducedWords, uECC_curve_n(DexcomG7ECCCurve()), numNWords) >= 0) {
        uECC_vli_sub(reducedWords, reducedWords, uECC_curve_n(DexcomG7ECCCurve()), numNWords);
    }
    DexcomG7ECCScalarNativeToBytes(result, reducedWords);
}

void DexcomG7ECCScalarFromBytes(const uint8_t *bytes,
                                size_t length,
                                uint8_t result[DexcomG7ECCScalarSize]) {
    memset(result, 0, DexcomG7ECCScalarSize);
    if (bytes == NULL || length == 0) {
        return;
    }

    // Retain the least significant 32 bytes of a longer digest or left-pad a shorter value. The
    // caller performs any required modular reduction after this fixed-width conversion.
    if (length >= DexcomG7ECCScalarSize) {
        memcpy(result, bytes + (length - DexcomG7ECCScalarSize), DexcomG7ECCScalarSize);
    } else {
        memcpy(result + (DexcomG7ECCScalarSize - length), bytes, length);
    }
}
