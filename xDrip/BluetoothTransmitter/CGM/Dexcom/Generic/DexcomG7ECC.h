#ifndef DexcomG7ECC_h
#define DexcomG7ECC_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// P-256 uses 32-byte scalars and two 32-byte coordinates for each raw affine point.
enum {
    DexcomG7ECCScalarSize = 32,
    DexcomG7ECCPointSize = 64
};

/// Generates one cryptographically random P-256 private scalar and its public point.
bool DexcomG7ECCGenerateKeyPair(uint8_t publicKey[DexcomG7ECCPointSize],
                                uint8_t privateKey[DexcomG7ECCScalarSize]);

/// Rejects malformed, off-curve, and otherwise invalid raw public points.
bool DexcomG7ECCIsValidPoint(const uint8_t point[DexcomG7ECCPointSize]);

/// Adds two affine P-256 points and returns false when the result is the point at infinity.
bool DexcomG7ECCPointAdd(const uint8_t left[DexcomG7ECCPointSize],
                         const uint8_t right[DexcomG7ECCPointSize],
                         uint8_t result[DexcomG7ECCPointSize]);

/// Subtracts the right affine point from the left by negating its Y coordinate before addition.
bool DexcomG7ECCPointSubtract(const uint8_t left[DexcomG7ECCPointSize],
                              const uint8_t right[DexcomG7ECCPointSize],
                              uint8_t result[DexcomG7ECCPointSize]);

/// Multiplies an arbitrary validated affine point by a scalar.
bool DexcomG7ECCPointMultiply(const uint8_t point[DexcomG7ECCPointSize],
                              const uint8_t scalar[DexcomG7ECCScalarSize],
                              uint8_t result[DexcomG7ECCPointSize]);

/// Multiplies the standard P-256 generator by a scalar.
bool DexcomG7ECCGeneratorMultiply(const uint8_t scalar[DexcomG7ECCScalarSize],
                                  uint8_t result[DexcomG7ECCPointSize]);

/// Produces a cryptographically random non-zero scalar below the P-256 group order.
bool DexcomG7ECCScalarRandom(uint8_t scalar[DexcomG7ECCScalarSize]);

/// Multiplies two scalars modulo the P-256 group order.
bool DexcomG7ECCScalarMultiplyModN(const uint8_t left[DexcomG7ECCScalarSize],
                                   const uint8_t right[DexcomG7ECCScalarSize],
                                   uint8_t result[DexcomG7ECCScalarSize]);

/// Subtracts the right scalar from the left modulo the P-256 group order.
bool DexcomG7ECCScalarSubtractModN(const uint8_t left[DexcomG7ECCScalarSize],
                                   const uint8_t right[DexcomG7ECCScalarSize],
                                   uint8_t result[DexcomG7ECCScalarSize]);

/// Reduces one 32-byte value into the valid scalar field.
void DexcomG7ECCScalarReduceModN(const uint8_t scalar[DexcomG7ECCScalarSize],
                                 uint8_t result[DexcomG7ECCScalarSize]);

/// Hashes or truncates arbitrary input into a 32-byte value, then reduces it modulo the group order.
void DexcomG7ECCScalarFromBytes(const uint8_t *bytes,
                                size_t length,
                                uint8_t result[DexcomG7ECCScalarSize]);

#ifdef __cplusplus
}
#endif

#endif
