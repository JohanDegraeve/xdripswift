#import "DexcomG7AuthBridge.h"

#import "AESCrypt.h"
#import "DexcomG7ECC.h"

#import <CommonCrypto/CommonDigest.h>
#import <objc/message.h>
#import <Security/Security.h>

// This bridge owns the cryptographic work required only by G7 Primary mode. The Swift
// `DexcomG7AuthSession` owns the BLE state machine and calls this object when a packet must be
// created or validated. Keeping those responsibilities separate prevents Primary authentication
// state from leaking into the much simpler Coexistence path.
//
// A sensor without a confirmed shared key starts the J-PAKE ownership exchange using the
// four-digit applicator code. The derived 16-byte key remains session-only until the sensor has
// acknowledged the final ownership step. Later connections can then use the short challenge path.
//
// The packet sequence and party identities were cross-checked against the open-source Juggluco
// implementation: https://github.com/j-kaltes/Juggluco
typedef NS_ENUM(NSInteger, DexcomG7AuthBridgeErrorCode) {
    DexcomG7AuthBridgeErrorCodeMissingTransmitterID = 1,
    DexcomG7AuthBridgeErrorCodeInvalidChallenge = 2,
    DexcomG7AuthBridgeErrorCodeUnavailable = 3,
    DexcomG7AuthBridgeErrorCodeInvalidCertificatePhase = 4,
    DexcomG7AuthBridgeErrorCodeMissingPrivateKey = 5,
    DexcomG7AuthBridgeErrorCodeSignatureFailed = 6,
    DexcomG7AuthBridgeErrorCodeInvalidPairingCode = 7,
    DexcomG7AuthBridgeErrorCodeInvalidPakePacket = 8,
    DexcomG7AuthBridgeErrorCodeValidationFailed = 9,
    DexcomG7AuthBridgeErrorCodeMissingSharedKey = 10,
};

static NSString * const DexcomG7AuthBridgeErrorDomain = @"DexcomG7AuthBridgeErrorDomain";

// Fixed client certificate material used by the known G7 ownership protocol. Parts A and B are
// sent during certificate phases zero and one. Part C is the matching raw P-256 signing scalar
// used only for the later proof-of-possession challenge.
static NSString * const G7KeksPartAHex =
@"308201EA3082018FA00302010202142F3C52B6EB08701046D45D78CE81784C9DFE5240300A06082A8648CE3D04030230133111300F06035504030C084445583030504731301E170D3230313033303135353930345A170D3335313032373135353930345A30133111300F06035504030C0844455830335047313059301306072A8648CE3D020106082A8648CE3D03010703420004FB1ACA21D8AEEC9A4EB51F85304953D977A1AD569799250FF863987F42A3CD9FA4FF571EB568BC6C396277C3DCB51DEDAEE85513C80A5C4435538A19F5A96348A381C03081BD300F0603551D130101FF040530030101FF301F0603551D230418301680149E0F1E36F3F276A701FE8E883A6E26A635BD6AFC305A0603551D1F04533051304FA034A0328630687474703A2F2F63726C2E64702E736161732E7072696D656B65792E636F6D2F63726C2F44455830305047312E63726CA217A41530133111300F06035504030C084445583030504731301D0603551D0E0416041488F61E81BC4B17F05C6B1BE2991D60087CCEDD79300E0603551D0F0101FF040403020186300A06082A8648CE3D0403020349003046022100AA69CD897EC663AF5F9E158187DF6851FF0756F00C401624564F81A19F5A0785022100DAEBB9FDB163B731EB0661F1C0A1932871A50E399AD1C6F519EABD4C9E7BA013";
static NSString * const G7KeksPartBHex =
@"308201CD30820174A003020102021419052FCC17530BFA56E49DCAFCDACF853CE5BA73300A06082A8648CE3D04030230133111300F06035504030C084445583033504731301E170D3233303431343130323831345A170D3235303431333130323831335A303A3138303606035504030C2F30312C303030302C303330304C514543437A4142417741412C63696F69653356625132686C5A4D6A64556D357267413059301306072A8648CE3D020106082A8648CE3D030107034200045118C35E9E41E7E0654FEE801C52A9C5DFC510EF09597D5CCA8461E4AF9C666714834F2BC903F16FABFC45755B0183F1A09745CDFFCB4E2F799E50BED9A6B58CA37F307D300C0603551D130101FF04023000301F0603551D2304183016801488F61E81BC4B17F05C6B1BE2991D60087CCEDD79301D0603551D250416301406082B0601050507030206082B06010505070301301D0603551D0E04160414D309E75C0725412D7A7922E3AACFB27F7EBD6BE0300E0603551D0F0101FF0404030205A0300A06082A8648CE3D0403020347003044022048D4868CF393D9044101B6F07FD68D7F0642805F85DA74E2FE9DE8DD3507F02702201CD1BF7C6C7EDD59435E324925FCF0EBB3CAE2110D79407C77AA3B93B7BC04CB";
static NSString * const G7KeksPartCRawScalarHex =
@"007CFBD596F6E74477B8C0E9F6F7A174275E101EF6BF7D18CAF01181D127B579";

static const uint8_t G7AlicePartyBytes[] = {0x63, 0x6c, 0x69, 0x65, 0x6e, 0x74}; /* "client" */
// Juggluco's captured round-1 vector validates against the ASCII peer identity
// used by xDrip+/KEKS, not its nibble-transformed Bob constant.
static const uint8_t G7BobPartyBytes[] = {0x73, 0x65, 0x72, 0x76, 0x65, 0x72}; /* "server" */

static const NSUInteger DexcomG7PakePacketSize = 160;

@interface G7PakePacket : NSObject

// The 64-byte affine public point being proved by this J-PAKE packet.
@property(nonatomic, strong) NSData *publicKey;

// The 64-byte temporary affine point used by the Schnorr-style proof.
@property(nonatomic, strong) NSData *proofPoint;

// The 32-byte proof scalar that completes the zero-knowledge proof equation.
@property(nonatomic, strong) NSData *proofScalar;

@end

@implementation G7PakePacket
@end

@interface DexcomG7AuthBridge ()

// DER certificate bytes sent during certificate exchange phase zero.
@property(nonatomic, strong) NSData *partA;

// DER certificate bytes sent during certificate exchange phase one.
@property(nonatomic, strong) NSData *partB;

// Candidate or confirmed 16-byte key used by the normal AES challenge response.
@property(nonatomic, strong, nullable) NSData *sharedKey;

// Advertised sensor name that owns the in-memory shared key and prevents cross-sensor reuse.
@property(nonatomic, copy, nullable) NSString *sharedKeyOwnerTransmitterID;

// Random token sent in the latest authentication request and later checked against the sensor hash.
@property(nonatomic, strong, nullable) NSData *lastAuthRequestToken;

// First local P-256 private scalar used for J-PAKE round one.
@property(nonatomic, strong, nullable) NSData *privateKeyA;

// Public point belonging to the first local private scalar.
@property(nonatomic, strong, nullable) NSData *publicKeyA;

// Second local P-256 private scalar used for J-PAKE round two.
@property(nonatomic, strong, nullable) NSData *privateKeyB;

// Public point belonging to the second local private scalar.
@property(nonatomic, strong, nullable) NSData *publicKeyB;

// Validated remote packet retained because later J-PAKE phases depend on its public point.
@property(nonatomic, strong, nullable) G7PakePacket *remoteRound1Packet;

// Second validated remote packet retained for round-three point and scalar calculations.
@property(nonatomic, strong, nullable) G7PakePacket *remoteRound2Packet;

// Validated remote round-three packet retained until the final shared point is derived.
@property(nonatomic, strong, nullable) G7PakePacket *remoteRound3Packet;

// Diagnostic label distinguishing a restored key from a newly derived candidate key.
@property(nonatomic, copy, readwrite) NSString *lastResolvedAuthKeyLabel;

@end

// Keep the original namespace so existing ownership keys survive this structural rename.
static NSString *DexcomG7SharedKeyDefaultsPrefix = @"G7NativeAuthBridge.SharedKey.";

@implementation DexcomG7AuthBridge

+ (void)clearPersistedSharedKeysForTransmitterID:(NSString *)transmitterID {
    if (transmitterID.length == 0) {
        return;
    }

    // Remove the original unsuffixed key and all three slot-specific keys. Keeping the legacy
    // removal makes deleting a sensor a complete reset across versions of the implementation.
    NSString *baseKey = [DexcomG7SharedKeyDefaultsPrefix stringByAppendingString:transmitterID];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:baseKey];
    for (NSNumber *slot in @[@1, @2, @3]) {
        [defaults removeObjectForKey:[baseKey stringByAppendingFormat:@".%02X", slot.unsignedCharValue]];
    }
}

- (instancetype)initWithTransmitterID:(NSString * _Nullable)transmitterID
                          pairingCode:(NSString * _Nullable)pairingCode
                   authenticationSlot:(uint8_t)authenticationSlot {
    self = [super init];
    if (self) {
        _transmitterID = [transmitterID copy];
        _pairingCode = [pairingCode copy];
        _authenticationSlot = authenticationSlot;
        // These constants are conventional DER/raw-scalar hex, exactly as sent by
        // Juggluco. Dexcom's nibble-ordered diagnostic hex decoder corrupts them.
        _partA = [DexcomG7AuthBridge dataFromHexString:G7KeksPartAHex];
        _partB = [DexcomG7AuthBridge dataFromHexString:G7KeksPartBHex];
        [self restorePersistedSharedKeyIfPossible];
    }
    return self;
}

// Changing the authentication slot changes the identity presented to the sensor. A key confirmed
// for one slot must never be reused for another slot, even when the transmitter ID is unchanged.
- (void)setAuthenticationSlot:(uint8_t)authenticationSlot {
    if (_authenticationSlot == authenticationSlot) {
        return;
    }

    _authenticationSlot = authenticationSlot;
    self.sharedKey = nil;
    self.sharedKeyOwnerTransmitterID = nil;
    self.lastAuthRequestToken = nil;
    [self restorePersistedSharedKeyIfPossible];
}

// A reconnect starts with fresh packet and J-PAKE state. A previously confirmed shared key is
// deliberately restored because it belongs to the saved sensor and authentication slot, not to a
// single Core Bluetooth connection.
- (void)resetSession {
    self.lastAuthRequestToken = nil;
    self.privateKeyA = nil;
    self.publicKeyA = nil;
    self.privateKeyB = nil;
    self.publicKeyB = nil;
    self.remoteRound1Packet = nil;
    self.remoteRound2Packet = nil;
    self.remoteRound3Packet = nil;
    self.lastResolvedAuthKeyLabel = @"unresolved";
    [self restorePersistedSharedKeyIfPossible];
}

- (void)clearSharedKey {
    self.sharedKey = nil;
    self.sharedKeyOwnerTransmitterID = nil;
    NSString *defaultsKey = [self sharedKeyDefaultsKey];
    if (defaultsKey.length > 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultsKey];
    }
}

// Select the short challenge path only when a confirmed key exists. Otherwise create both local
// J-PAKE key pairs before asking the sensor to begin the ownership exchange.
- (NSData * _Nullable)initialControlPacket:(NSError **)error {
    [self restorePersistedSharedKeyIfPossible];
    if (self.sharedKey != nil) {
        return [self makeAuthRequest];
    }

    if (![self ensureLocalPakeKeyPairs:error]) {
        return nil;
    }

    return [NSData dataWithBytes:(const uint8_t[]){0x0A, 0x00} length:2];
}

- (NSData *)makeAuthRequest {
    // Dexcom authentication uses the first eight bytes of a fresh UUID as a single-use token. The
    // final byte selects the independent authentication slot presented to the sensor.
    uuid_t uuidBytes;
    [[NSUUID UUID] getUUIDBytes:uuidBytes];

    NSMutableData *data = [NSMutableData dataWithCapacity:10];
    uint8_t opcode = 0x02;
    [data appendBytes:&opcode length:1];
    [data appendBytes:uuidBytes length:8];

    uint8_t slot = self.authenticationSlot;
    [data appendBytes:&slot length:1];
    self.lastAuthRequestToken = [NSData dataWithBytes:uuidBytes length:8];
    return data;
}

- (NSData * _Nullable)authChallengeResponseForTokenHash:(NSData *)tokenHash
                                              challenge:(NSData *)challenge
                                                  error:(NSError **)error {
    if (challenge.length != 8) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeInvalidChallenge
                                     userInfo:@{NSLocalizedDescriptionKey: @"Expected an 8-byte Dexcom challenge."}];
        }
        return nil;
    }

    NSData *authKey = [self currentAuthKey:error];
    if (authKey == nil) {
        return nil;
    }

    if (tokenHash.length == 8 && self.lastAuthRequestToken.length == 8) {
        // Validate the sensor's hash of our single-use token when both values are available. Some
        // firmware captures disagree on this diagnostic value, so a mismatch is logged while the
        // independently supplied sensor challenge remains authoritative for the response.
        NSData *expected = [self challengeHashForChallenge:self.lastAuthRequestToken usingKey:authKey error:error];
        if (expected == nil) {
            return nil;
        }
        if (![expected isEqualToData:tokenHash]) {
            NSLog(@"DexcomG7AuthBridge: transmitter token hash %@ did not match locally derived value %@. Continuing with challenge response",
                  tokenHash, expected);
        }
    }

    NSData *hash = [self challengeHashForChallenge:challenge usingKey:authKey error:error];
    if (hash == nil) {
        return nil;
    }

    NSMutableData *response = [NSMutableData dataWithCapacity:9];
    uint8_t opcode = 0x04;
    [response appendBytes:&opcode length:1];
    [response appendData:hash];
    return response;
}

- (NSData * _Nullable)certificateRequestForPhase:(uint8_t)phase
                                           error:(NSError **)error {
    uint32_t size = 0;
    switch (phase) {
        case 0:
            size = (uint32_t)self.partA.length;
            break;
        case 1:
            size = (uint32_t)self.partB.length;
            break;
        case 2:
            // The final certificate-exchange command carries no certificate.
            // It closes the exchange before proof-of-possession begins.
            size = 0;
            break;
        default:
            if (error != NULL) {
                *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                             code:DexcomG7AuthBridgeErrorCodeInvalidCertificatePhase
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unsupported G7 certificate phase."}];
            }
            return nil;
    }

    NSMutableData *data = [NSMutableData dataWithCapacity:6];
    uint8_t opcode = 0x0B;
    [data appendBytes:&opcode length:1];
    [data appendBytes:&phase length:1];
    // Android KEKS/Juggluco use `LITTLE_ENDIAN` for the 32-bit certificate length.
    // The previous big-endian request produced 0b000000005b, which the transmitter
    // accepted at the write layer but immediately disconnected after.
    uint32_t littleEndianSize = CFSwapInt32HostToLittle(size);
    [data appendBytes:&littleEndianSize length:sizeof(littleEndianSize)];
    return data;
}

- (NSArray<NSData *> * _Nullable)certificateStreamPacketsForPhase:(uint8_t)phase
                                                            error:(NSError **)error {
    NSData *payload = nil;
    switch (phase) {
        case 0:
            payload = self.partA;
            break;
        case 1:
            payload = self.partB;
            break;
        case 2:
            return @[];
        default:
            if (error != NULL) {
                *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                             code:DexcomG7AuthBridgeErrorCodeInvalidCertificatePhase
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unsupported G7 certificate phase."}];
            }
            return nil;
    }

    const uint8_t *bytes = (const uint8_t *)payload.bytes;
    if (payload.length < 2 || bytes[0] != 0x30 || bytes[1] != 0x82) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeInvalidCertificatePhase
                                     userInfo:@{NSLocalizedDescriptionKey: @"G7 client certificate is not valid DER wire data."}];
        }
        return nil;
    }

    return [self chunkedPacketsForData:payload];
}

- (NSData *)makeProofOfPossessionChallengeRequest {
    // Prefer the system cryptographic random source for the 16-byte challenge. UUID bytes retain
    // the required uniqueness as a defensive fallback if Security unexpectedly fails.
    NSMutableData *challenge = [NSMutableData dataWithLength:16];
    int result = SecRandomCopyBytes(kSecRandomDefault, challenge.length, challenge.mutableBytes);
    if (result != errSecSuccess) {
        uuid_t uuidBytes;
        [[NSUUID UUID] getUUIDBytes:uuidBytes];
        [challenge replaceBytesInRange:NSMakeRange(0, 16) withBytes:uuidBytes];
    }

    NSMutableData *request = [NSMutableData dataWithCapacity:17];
    uint8_t opcode = 0x0C;
    [request appendBytes:&opcode length:1];
    [request appendData:challenge];
    return request;
}

- (NSData * _Nullable)handlePakePayloadForPhase:(uint8_t)phase
                                        payload:(NSData *)payload
                                  streamPackets:(NSArray<NSData *> * _Nullable * _Nullable)streamPackets
                                          error:(NSError **)error {
    if (streamPackets != NULL) {
        *streamPackets = nil;
    }

    if (![self ensureLocalPakeKeyPairs:error]) {
        return nil;
    }

    G7PakePacket *packet = [self parsePakePacket:payload error:error];
    if (packet == nil) {
        return nil;
    }

    NSData *controlPacket = nil;
    NSArray<NSData *> *outboundStreamPackets = nil;

    // Each remote phase is validated before its state is retained. The matching local payload is
    // returned as stream fragments, while the small control packet tells the sensor which phase
    // can be processed next.
    switch (phase) {
        case 0: {
            if (![self validateRound12Packet:packet party:[NSData dataWithBytes:G7BobPartyBytes length:sizeof(G7BobPartyBytes)] error:error]) {
                return nil;
            }
            self.remoteRound1Packet = packet;

            NSData *localRound1 = [self makeRound12PacketForPrivateKey:self.privateKeyA
                                                             publicKey:self.publicKeyA
                                                                  base:nil
                                                                 party:[NSData dataWithBytes:G7AlicePartyBytes length:sizeof(G7AlicePartyBytes)]
                                                                 error:error];
            if (localRound1 == nil) {
                return nil;
            }

            controlPacket = [NSData dataWithBytes:(const uint8_t[]){0x0A, 0x01} length:2];
            outboundStreamPackets = [self chunkedPacketsForData:localRound1];
            break;
        }

        case 1: {
            if (![self validateRound12Packet:packet party:[NSData dataWithBytes:G7BobPartyBytes length:sizeof(G7BobPartyBytes)] error:error]) {
                return nil;
            }
            self.remoteRound2Packet = packet;

            NSData *localRound2 = [self makeRound12PacketForPrivateKey:self.privateKeyB
                                                             publicKey:self.publicKeyB
                                                                  base:nil
                                                                 party:[NSData dataWithBytes:G7AlicePartyBytes length:sizeof(G7AlicePartyBytes)]
                                                                 error:error];
            if (localRound2 == nil) {
                return nil;
            }

            controlPacket = [NSData dataWithBytes:(const uint8_t[]){0x0A, 0x02} length:2];
            outboundStreamPackets = [self chunkedPacketsForData:localRound2];
            break;
        }

        case 2: {
            self.remoteRound3Packet = packet;
            if (![self validateRound3Packet:packet error:error]) {
                return nil;
            }

            NSData *localRound3 = [self makeRound3Packet:error];
            if (localRound3 == nil) {
                return nil;
            }
            NSData *derivedSharedKey = [self deriveShortSharedKey:error];
            if (derivedSharedKey == nil) {
                return nil;
            }
            self.sharedKey = derivedSharedKey;
            self.sharedKeyOwnerTransmitterID = [self.transmitterID copy];

            controlPacket = [self makeAuthRequest];
            outboundStreamPackets = [self chunkedPacketsForData:localRound3];
            break;
        }

        default:
            if (error != NULL) {
                *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                             code:DexcomG7AuthBridgeErrorCodeUnavailable
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unsupported G7 J-PAKE phase."}];
            }
            return nil;
    }

    if (streamPackets != NULL) {
        *streamPackets = outboundStreamPackets;
    }
    return controlPacket;
}

- (NSData * _Nullable)proofOfPossessionResponseForChallenge:(NSData *)challenge
                                                      error:(NSError **)error {
    if (challenge.length < 16) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeInvalidChallenge
                                     userInfo:@{NSLocalizedDescriptionKey: @"Expected a 16-byte proof-of-possession challenge."}];
        }
        return nil;
    }

    Class signerClass = NSClassFromString(@"DexcomG7CryptoKitProofSigner");
    if (signerClass == Nil) {
        signerClass = NSClassFromString(@"xdrip.DexcomG7CryptoKitProofSigner");
    }
    SEL signerSelector = NSSelectorFromString(@"rawProofSignatureForChallenge:privateKeyRaw:error:");
    if (signerClass != Nil && [signerClass respondsToSelector:signerSelector]) {
        typedef NSData *(*SignerSend)(id, SEL, NSData *, NSData *, NSError **);
        SignerSend send = (SignerSend)objc_msgSend;
        NSData *signerKeyData = [DexcomG7AuthBridge dataFromHexString:G7KeksPartCRawScalarHex];
        if (signerKeyData.length != 32) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                             code:DexcomG7AuthBridgeErrorCodeMissingPrivateKey
                                         userInfo:@{NSLocalizedDescriptionKey: @"G7 proof private scalar is invalid."}];
            }
            return nil;
        }
        NSData *signature = send(signerClass, signerSelector, challenge, signerKeyData, error);
        if (signature.length == 64) {
            return signature;
        }
        if (signature != nil) {
            if (error != NULL && *error == nil) {
                *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                             code:DexcomG7AuthBridgeErrorCodeSignatureFailed
                                         userInfo:@{NSLocalizedDescriptionKey: @"CryptoKit proof signer returned an unexpected signature length."}];
            }
            return nil;
        }
        if (error != NULL && *error != nil) {
            return nil;
        }
    }

    if (error != NULL) {
        *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                     code:DexcomG7AuthBridgeErrorCodeSignatureFailed
                                 userInfo:@{NSLocalizedDescriptionKey: @"CryptoKit proof signer is unavailable in this build."}];
    }
    return nil;
}

// Persistence is intentionally keyed by transmitter ID and authentication slot. Slot 2 keeps the
// original unsuffixed key name so installations that used the first native implementation retain
// their already confirmed ownership key.
- (NSString * _Nullable)sharedKeyDefaultsKey {
    if (self.transmitterID.length == 0) {
        return nil;
    }
    NSString *transmitterKey = [DexcomG7SharedKeyDefaultsPrefix stringByAppendingString:self.transmitterID];
    // Preserve the original slot-2 key so existing working installations do not
    // need to repeat the ownership bootstrap after this setting is introduced.
    if (self.authenticationSlot == 0x02) {
        return transmitterKey;
    }
    return [transmitterKey stringByAppendingFormat:@".%02X", self.authenticationSlot];
}

- (void)restorePersistedSharedKeyIfPossible {
    if (self.transmitterID.length == 0) {
        self.sharedKey = nil;
        self.sharedKeyOwnerTransmitterID = nil;
        return;
    }

    if (self.sharedKey.length == 16 &&
        [self.sharedKeyOwnerTransmitterID isEqualToString:self.transmitterID]) {
        return;
    }

    NSString *defaultsKey = [self sharedKeyDefaultsKey];
    NSData *storedKey = defaultsKey.length > 0 ? [[NSUserDefaults standardUserDefaults] dataForKey:defaultsKey] : nil;
    if (storedKey.length == 16) {
        self.sharedKey = storedKey;
        self.sharedKeyOwnerTransmitterID = [self.transmitterID copy];
    } else {
        self.sharedKey = nil;
        self.sharedKeyOwnerTransmitterID = nil;
    }
}

- (void)persistSharedKeyIfPossible {
    if (self.sharedKey.length != 16 || self.transmitterID.length == 0) {
        return;
    }

    NSString *defaultsKey = [self sharedKeyDefaultsKey];
    if (defaultsKey.length == 0) {
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:self.sharedKey forKey:defaultsKey];
}

// Deriving a J-PAKE key is not enough to trust it on the next connection. The Swift state machine
// calls this only after the sensor confirms the ownership exchange, which prevents interrupted or
// rejected attempts from poisoning later short-auth connections.
- (void)confirmSharedKey {
    [self persistSharedKeyIfPossible];
}

- (NSData * _Nullable)currentAuthKey:(NSError **)error {
    [self restorePersistedSharedKeyIfPossible];
    if (self.sharedKey.length == 16) {
        self.lastResolvedAuthKeyLabel = @"persisted short-auth sharedKey";
        return self.sharedKey;
    }

    if (error != NULL) {
        *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                     code:DexcomG7AuthBridgeErrorCodeMissingSharedKey
                                 userInfo:@{NSLocalizedDescriptionKey: @"No confirmed G7 shared key is available for challenge authentication."}];
    }
    return nil;
}

- (NSData * _Nullable)challengeHashForChallenge:(NSData *)challenge
                                       usingKey:(NSData *)key
                                          error:(NSError **)error {
    NSMutableData *doubleChallenge = [NSMutableData dataWithCapacity:16];
    [doubleChallenge appendData:challenge];
    [doubleChallenge appendData:challenge];

    NSError *encryptError = nil;
    NSData *encrypted = [AESCrypt encryptData:doubleChallenge usingKey:key error:&encryptError];
    if (encrypted == nil || encrypted.length < 8) {
        if (error != NULL) {
            *error = encryptError ?: [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to encrypt Dexcom auth challenge."}];
        }
        return nil;
    }

    return [encrypted subdataWithRange:NSMakeRange(0, 8)];
}

- (BOOL)ensureLocalPakeKeyPairs:(NSError **)error {
    if (self.privateKeyA.length == DexcomG7ECCScalarSize &&
        self.publicKeyA.length == DexcomG7ECCPointSize &&
        self.privateKeyB.length == DexcomG7ECCScalarSize &&
        self.publicKeyB.length == DexcomG7ECCPointSize) {
        return YES;
    }

    if (self.pairingCode.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeInvalidPairingCode
                                     userInfo:@{NSLocalizedDescriptionKey: @"G7 authentication requires a pairing code before J-PAKE can start."}];
        }
        return NO;
    }

    uint8_t publicKey[DexcomG7ECCPointSize];
    uint8_t privateKey[DexcomG7ECCScalarSize];
    if (!DexcomG7ECCGenerateKeyPair(publicKey, privateKey)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate the first G7 J-PAKE key pair."}];
        }
        return NO;
    }
    self.publicKeyA = [NSData dataWithBytes:publicKey length:sizeof(publicKey)];
    self.privateKeyA = [NSData dataWithBytes:privateKey length:sizeof(privateKey)];

    if (!DexcomG7ECCGenerateKeyPair(publicKey, privateKey)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate the second G7 J-PAKE key pair."}];
        }
        return NO;
    }
    self.publicKeyB = [NSData dataWithBytes:publicKey length:sizeof(publicKey)];
    self.privateKeyB = [NSData dataWithBytes:privateKey length:sizeof(privateKey)];
    return YES;
}

// Each J-PAKE proof contains a public point, a proof point and a scalar. Point validation happens
// here before any packet is accepted by the higher-level authentication state machine.
- (G7PakePacket * _Nullable)parsePakePacket:(NSData *)data
                                      error:(NSError **)error {
    if (data.length < DexcomG7PakePacketSize) {
        if (error != NULL) {
            NSString *message = [NSString stringWithFormat:@"Expected a %lu-byte G7 J-PAKE packet, got %lu bytes.",
                                 (unsigned long)DexcomG7PakePacketSize,
                                 (unsigned long)data.length];
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeInvalidPakePacket
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    NSData *packetData = (data.length == DexcomG7PakePacketSize) ? data : [data subdataWithRange:NSMakeRange(0, DexcomG7PakePacketSize)];
    G7PakePacket *packet = [G7PakePacket new];
    packet.publicKey = [packetData subdataWithRange:NSMakeRange(0, DexcomG7ECCPointSize)];
    packet.proofPoint = [packetData subdataWithRange:NSMakeRange(DexcomG7ECCPointSize, DexcomG7ECCPointSize)];
    packet.proofScalar = [packetData subdataWithRange:NSMakeRange(DexcomG7ECCPointSize * 2, DexcomG7ECCScalarSize)];

    if (!DexcomG7ECCIsValidPoint((const uint8_t *)packet.publicKey.bytes) ||
        !DexcomG7ECCIsValidPoint((const uint8_t *)packet.proofPoint.bytes)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeValidationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Received an invalid elliptic-curve point in the G7 J-PAKE packet."}];
        }
        return nil;
    }

    return packet;
}

- (NSData * _Nullable)makeRound12PacketForPrivateKey:(NSData *)privateKey
                                           publicKey:(NSData *)publicKey
                                                base:(NSData * _Nullable)base
                                               party:(NSData *)party
                                               error:(NSError **)error {
    uint8_t exponent[DexcomG7ECCScalarSize];
    if (!DexcomG7ECCScalarRandom(exponent)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate the G7 J-PAKE exponent."}];
        }
        return nil;
    }

    NSData *basePoint = base ?: [self generatorPoint];
    uint8_t proofPoint[DexcomG7ECCPointSize];
    if (![self pointBytesFrom:basePoint multipliedByScalar:[NSData dataWithBytes:exponent length:sizeof(exponent)] output:proofPoint error:error]) {
        return nil;
    }

    NSData *hash = [self zeroKnowledgeHashForBase:basePoint
                                                gv:[NSData dataWithBytes:proofPoint length:sizeof(proofPoint)]
                                         publicKey:publicKey
                                             party:party];
    uint8_t product[DexcomG7ECCScalarSize];
    if (!DexcomG7ECCScalarMultiplyModN((const uint8_t *)hash.bytes, (const uint8_t *)privateKey.bytes, product)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to calculate the G7 J-PAKE proof product."}];
        }
        return nil;
    }

    uint8_t proofScalar[DexcomG7ECCScalarSize];
    if (!DexcomG7ECCScalarSubtractModN(exponent, product, proofScalar)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to calculate the G7 J-PAKE proof scalar."}];
        }
        return nil;
    }

    NSMutableData *packet = [NSMutableData dataWithCapacity:DexcomG7PakePacketSize];
    [packet appendData:publicKey];
    [packet appendBytes:proofPoint length:sizeof(proofPoint)];
    [packet appendBytes:proofScalar length:sizeof(proofScalar)];
    return packet;
}

- (BOOL)validateRound12Packet:(G7PakePacket *)packet
                        party:(NSData *)party
                        error:(NSError **)error {
    NSData *basePoint = [self generatorPoint];
    return [self validateZeroKnowledgePacket:packet basePoint:basePoint party:party error:error];
}

- (BOOL)validateRound3Packet:(G7PakePacket *)packet
                       error:(NSError **)error {
    if (self.remoteRound1Packet == nil || self.publicKeyA == nil || self.publicKeyB == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Round-3 validation is missing the earlier J-PAKE state."}];
        }
        return NO;
    }

    uint8_t combined[DexcomG7ECCPointSize];
    if (!DexcomG7ECCPointAdd((const uint8_t *)self.publicKeyA.bytes, (const uint8_t *)self.publicKeyB.bytes, combined) ||
        !DexcomG7ECCPointAdd(combined, (const uint8_t *)self.remoteRound1Packet.publicKey.bytes, combined)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct the G7 J-PAKE round-3 base point."}];
        }
        return NO;
    }

    NSData *basePoint = [NSData dataWithBytes:combined length:sizeof(combined)];
    return [self validateZeroKnowledgePacket:packet
                                   basePoint:basePoint
                                       party:[NSData dataWithBytes:G7BobPartyBytes length:sizeof(G7BobPartyBytes)]
                                       error:error];
}

// Validate the Schnorr-style zero-knowledge proof without exposing the elliptic-curve arithmetic
// to Swift. The peer identity is included in the hash so a proof created for the other role cannot
// be replayed as a client proof.
- (BOOL)validateZeroKnowledgePacket:(G7PakePacket *)packet
                          basePoint:(NSData *)basePoint
                              party:(NSData *)party
                              error:(NSError **)error {
    NSData *hash = [self zeroKnowledgeHashForBase:basePoint
                                                gv:packet.proofPoint
                                         publicKey:packet.publicKey
                                             party:party];

    uint8_t leftProduct[DexcomG7ECCPointSize];
    uint8_t rightProduct[DexcomG7ECCPointSize];
    uint8_t combined[DexcomG7ECCPointSize];
    if (![self pointBytesFrom:basePoint multipliedByScalar:packet.proofScalar output:leftProduct error:error] ||
        ![self pointBytesFrom:packet.publicKey multipliedByScalar:hash output:rightProduct error:error] ||
        !DexcomG7ECCPointAdd(leftProduct, rightProduct, combined)) {
        if (error != NULL && *error == nil) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeValidationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to validate the G7 J-PAKE zero-knowledge proof."}];
        }
        return NO;
    }

    if (memcmp(combined, packet.proofPoint.bytes, sizeof(combined)) != 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeValidationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"The G7 J-PAKE zero-knowledge proof did not validate."}];
        }
        return NO;
    }

    return YES;
}

// Round 3 combines both parties' first-round points with the applicator-code scalar. The resulting
// packet proves knowledge of the same code without transmitting the code itself.
- (NSData * _Nullable)makeRound3Packet:(NSError **)error {
    if (self.remoteRound1Packet == nil || self.remoteRound2Packet == nil ||
        self.publicKeyA == nil || self.privateKeyB == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot build the G7 J-PAKE round-3 packet without the earlier rounds."}];
        }
        return nil;
    }

    NSData *passwordScalar = [self passwordScalar:error];
    if (passwordScalar == nil) {
        return nil;
    }

    uint8_t x2s[DexcomG7ECCScalarSize];
    if (!DexcomG7ECCScalarMultiplyModN((const uint8_t *)self.privateKeyB.bytes, (const uint8_t *)passwordScalar.bytes, x2s)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to derive the round-3 J-PAKE scalar."}];
        }
        return nil;
    }

    uint8_t g134[DexcomG7ECCPointSize];
    if (!DexcomG7ECCPointAdd((const uint8_t *)self.publicKeyA.bytes, (const uint8_t *)self.remoteRound1Packet.publicKey.bytes, g134) ||
        !DexcomG7ECCPointAdd(g134, (const uint8_t *)self.remoteRound2Packet.publicKey.bytes, g134)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct the round-3 base point for G7 primary auth."}];
        }
        return nil;
    }

    uint8_t publicPoint[DexcomG7ECCPointSize];
    if (!DexcomG7ECCPointMultiply(g134, x2s, publicPoint)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct the local G7 round-3 public point."}];
        }
        return nil;
    }

    return [self makeRound12PacketForPrivateKey:[NSData dataWithBytes:x2s length:sizeof(x2s)]
                                      publicKey:[NSData dataWithBytes:publicPoint length:sizeof(publicPoint)]
                                           base:[NSData dataWithBytes:g134 length:sizeof(g134)]
                                          party:[NSData dataWithBytes:G7AlicePartyBytes length:sizeof(G7AlicePartyBytes)]
                                          error:error];
}

// The final point is reduced through SHA-256 to the 16-byte AES key used by the normal Dexcom
// challenge and response exchange. This key is still only a candidate until `confirmSharedKey`.
- (NSData * _Nullable)deriveShortSharedKey:(NSError **)error {
    if (self.remoteRound2Packet == nil || self.remoteRound3Packet == nil || self.privateKeyB == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeMissingSharedKey
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cannot derive the G7 primary shared key until all J-PAKE rounds have completed."}];
        }
        return nil;
    }

    NSData *passwordScalar = [self passwordScalar:error];
    if (passwordScalar == nil) {
        return nil;
    }

    uint8_t x2s[DexcomG7ECCScalarSize];
    if (!DexcomG7ECCScalarMultiplyModN((const uint8_t *)self.privateKeyB.bytes, (const uint8_t *)passwordScalar.bytes, x2s)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to derive the G7 primary shared-key scalar."}];
        }
        return nil;
    }

    uint8_t subtractPoint[DexcomG7ECCPointSize];
    uint8_t keyPoint[DexcomG7ECCPointSize];
    if (!DexcomG7ECCPointMultiply((const uint8_t *)self.remoteRound2Packet.publicKey.bytes, x2s, subtractPoint) ||
        !DexcomG7ECCPointSubtract((const uint8_t *)self.remoteRound3Packet.publicKey.bytes, subtractPoint, keyPoint) ||
        !DexcomG7ECCPointMultiply(keyPoint, (const uint8_t *)self.privateKeyB.bytes, keyPoint)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to derive the G7 primary shared-key point."}];
        }
        return nil;
    }

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(keyPoint, DexcomG7ECCScalarSize, digest);
    return [NSData dataWithBytes:digest length:16];
}

- (NSData * _Nullable)passwordScalar:(NSError **)error {
    if (self.pairingCode.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeInvalidPairingCode
                                     userInfo:@{NSLocalizedDescriptionKey: @"Missing pairing code for G7 primary J-PAKE."}];
        }
        return nil;
    }

    NSData *ascii = [self.pairingCode dataUsingEncoding:NSUTF8StringEncoding];
    if (ascii.length == 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeInvalidPairingCode
                                     userInfo:@{NSLocalizedDescriptionKey: @"The pairing code could not be encoded as ASCII bytes."}];
        }
        return nil;
    }

    NSMutableData *passwordBytes = [NSMutableData data];
    if (self.pairingCode.length == 6) {
        uint8_t prefix[] = {0x30, 0x30};
        [passwordBytes appendBytes:prefix length:sizeof(prefix)];
    }
    [passwordBytes appendData:ascii];

    uint8_t scalar[DexcomG7ECCScalarSize];
    DexcomG7ECCScalarFromBytes((const uint8_t *)passwordBytes.bytes, passwordBytes.length, scalar);
    return [NSData dataWithBytes:scalar length:sizeof(scalar)];
}

- (NSData *)zeroKnowledgeHashForBase:(NSData *)basePoint
                                  gv:(NSData *)proofPoint
                           publicKey:(NSData *)publicKey
                               party:(NSData *)party {
    NSMutableData *input = [NSMutableData data];
    [self appendDigestField:[self uncompressedPointFromRawPoint:basePoint] to:input];
    [self appendDigestField:[self uncompressedPointFromRawPoint:proofPoint] to:input];
    [self appendDigestField:[self uncompressedPointFromRawPoint:publicKey] to:input];
    [self appendDigestField:party to:input];

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(input.bytes, (CC_LONG)input.length, digest);
    uint8_t reducedDigest[DexcomG7ECCScalarSize];
    DexcomG7ECCScalarReduceModN(digest, reducedDigest);
    return [NSData dataWithBytes:reducedDigest length:sizeof(reducedDigest)];
}

- (void)appendDigestField:(NSData *)field
                       to:(NSMutableData *)buffer {
    uint32_t length = CFSwapInt32HostToBig((uint32_t)field.length);
    [buffer appendBytes:&length length:sizeof(length)];
    [buffer appendData:field];
}

- (NSData *)uncompressedPointFromRawPoint:(NSData *)point {
    NSMutableData *data = [NSMutableData dataWithCapacity:point.length + 1];
    uint8_t prefix = 0x04;
    [data appendBytes:&prefix length:1];
    [data appendData:point];
    return data;
}

- (NSData *)generatorPoint {
    static NSData *generator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const uint8_t point[DexcomG7ECCPointSize] = {
            0x6b, 0x17, 0xd1, 0xf2, 0xe1, 0x2c, 0x42, 0x47,
            0xf8, 0xbc, 0xe6, 0xe5, 0x63, 0xa4, 0x40, 0xf2,
            0x77, 0x03, 0x7d, 0x81, 0x2d, 0xeb, 0x33, 0xa0,
            0xf4, 0xa1, 0x39, 0x45, 0xd8, 0x98, 0xc2, 0x96,
            0x4f, 0xe3, 0x42, 0xe2, 0xfe, 0x1a, 0x7f, 0x9b,
            0x8e, 0xe7, 0xeb, 0x4a, 0x7c, 0x0f, 0x9e, 0x16,
            0x2b, 0xce, 0x33, 0x57, 0x6b, 0x31, 0x5e, 0xce,
            0xcb, 0xb6, 0x40, 0x68, 0x37, 0xbf, 0x51, 0xf5
        };
        generator = [NSData dataWithBytes:point length:sizeof(point)];
    });
    return generator;
}

- (BOOL)pointBytesFrom:(NSData *)point
   multipliedByScalar:(NSData *)scalar
                output:(uint8_t[DexcomG7ECCPointSize])output
                 error:(NSError **)error {
    if (point.length != DexcomG7ECCPointSize || scalar.length != DexcomG7ECCScalarSize) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid point/scalar length for G7 primary ECC math."}];
        }
        return NO;
    }

    if (!DexcomG7ECCPointMultiply((const uint8_t *)point.bytes, (const uint8_t *)scalar.bytes, output)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DexcomG7AuthBridgeErrorDomain
                                         code:DexcomG7AuthBridgeErrorCodeUnavailable
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to multiply the G7 primary ECC point."}];
        }
        return NO;
    }
    return YES;
}

- (NSArray<NSData *> *)chunkedPacketsForData:(NSData *)data {
    if (data.length == 0) {
        return @[];
    }

    NSMutableArray<NSData *> *packets = [NSMutableArray array];
    NSUInteger offset = 0;
    while (offset < data.length) {
        NSUInteger length = MIN((NSUInteger)20, data.length - offset);
        [packets addObject:[data subdataWithRange:NSMakeRange(offset, length)]];
        offset += length;
    }
    return packets;
}

+ (NSData *)dataFromHexString:(NSString *)hexString {
    NSMutableData *data = [NSMutableData dataWithCapacity:hexString.length / 2];
    NSUInteger index = 0;
    while (index + 1 < hexString.length) {
        unsigned int value = 0;
        NSString *byteString = [hexString substringWithRange:NSMakeRange(index, 2)];
        [[NSScanner scannerWithString:byteString] scanHexInt:&value];
        uint8_t byte = (uint8_t)value;
        [data appendBytes:&byte length:1];
        index += 2;
    }
    return data;
}

@end
