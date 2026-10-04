#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C boundary that owns G7 cryptographic state and persisted primary authentication
/// keys. Swift coordinates BLE packet order through `DexcomG7AuthSession`, while this bridge keeps
/// the J-PAKE arithmetic, AES challenge response, certificate data, and proof key material together.
@interface DexcomG7AuthBridge : NSObject

/// Advertised `DX...` name that scopes persisted authentication material to one physical sensor.
@property(nonatomic, copy, nullable) NSString *transmitterID;

/// Four decimal digits from the applicator label used as the J-PAKE password input.
@property(nonatomic, copy, nullable) NSString *pairingCode;

/// Independent sensor authentication identity selected for primary mode.
@property(nonatomic) uint8_t authenticationSlot;

/// Human-readable description of the key selected for the most recent challenge response.
@property(nonatomic, copy, readonly) NSString *lastResolvedAuthKeyLabel;

/// Removes every persisted primary key for one sensor after the user deletes and adds it again.
+ (void)clearPersistedSharedKeysForTransmitterID:(NSString *)transmitterID
    NS_SWIFT_NAME(clearPersistedSharedKeys(forTransmitterID:));

/// Creates a bridge with the complete identity needed to resolve or derive one slot-specific key.
- (instancetype)initWithTransmitterID:(nullable NSString *)transmitterID
                          pairingCode:(nullable NSString *)pairingCode
                   authenticationSlot:(uint8_t)authenticationSlot NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// Clears packet and candidate-key state for a new BLE connection while preserving a confirmed key.
- (void)resetSession;

/// Removes both the in-memory and persisted shared key for the current sensor and slot.
- (void)clearSharedKey;

/// Persists the candidate key only after the sensor acknowledges final ownership.
- (void)confirmSharedKey;

/// Returns either the saved-key short-auth request or the opening control packet for full J-PAKE.
- (nullable NSData *)initialControlPacket:(NSError **)error;

/// Builds the normal AES response to the token and challenge supplied by the sensor.
- (nullable NSData *)authChallengeResponseForTokenHash:(NSData *)tokenHash
                                             challenge:(NSData *)challenge
                                                 error:(NSError **)error;

/// Creates the control request that begins one ordered certificate phase.
- (nullable NSData *)certificateRequestForPhase:(uint8_t)phase
                                          error:(NSError **)error;

/// Returns the local certificate bytes split into BLE-sized stream packets for one phase.
- (nullable NSArray<NSData *> *)certificateStreamPacketsForPhase:(uint8_t)phase
                                                           error:(NSError **)error;

/// Creates the random local challenge that starts proof of possession.
- (NSData *)makeProofOfPossessionChallengeRequest;

/// Validates one remote J-PAKE payload, advances the key agreement, and returns the response packets.
- (nullable NSData *)handlePakePayloadForPhase:(uint8_t)phase
                                       payload:(NSData *)payload
                                 streamPackets:(NSArray<NSData *> * _Nullable * _Nullable)streamPackets
                                         error:(NSError **)error;

/// Validates the remote ownership proof and signs the supplied sensor challenge with the local key.
- (nullable NSData *)proofOfPossessionResponseForChallenge:(NSData *)challenge
                                                     error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
