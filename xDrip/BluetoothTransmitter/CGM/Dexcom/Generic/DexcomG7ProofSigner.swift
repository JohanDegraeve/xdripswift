import CryptoKit
import Foundation

/// Small Objective-C-visible boundary around CryptoKit's P-256 signing support.
///
/// The authentication bridge is Objective-C because it also calls the C micro-ecc wrapper. Keeping
/// the actual signature operation here lets CryptoKit validate and sign with the private key while
/// the bridge receives the fixed 64-byte raw signature required by the G7 wire protocol.
@objc(DexcomG7CryptoKitProofSigner)
final class DexcomG7CryptoKitProofSigner: NSObject {
    @objc(rawProofSignatureForChallenge:privateKeyRaw:error:)
    static func rawProofSignature(
        forChallenge challenge: NSData,
        privateKeyRaw: NSData,
        error errorPointer: NSErrorPointer
    ) -> NSData? {
        do {
            // CryptoKit validates that the raw 32-byte scalar can represent a P-256 signing key.
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyRaw as Data)

            // Dexcom signs the SHA-256 digest of the 16-byte challenge. Return the fixed-width
            // `r || s` representation expected by `Auth_Stream` rather than a DER signature.
            let digest = SHA256.hash(data: challenge as Data)
            return try privateKey.signature(for: digest).rawRepresentation as NSData
        } catch {
            // Objective-C cannot catch Swift errors directly, so pass the exact CryptoKit failure
            // through the conventional NSError out parameter used by the authentication bridge.
            errorPointer?.pointee = error as NSError
            return nil
        }
    }
}
