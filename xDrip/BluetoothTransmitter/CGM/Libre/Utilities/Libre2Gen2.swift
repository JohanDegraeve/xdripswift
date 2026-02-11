import Foundation
import os

#if !os(watchOS)
import CoreNFC
#endif

/// Libre 2 Gen2 (US/CA/AU models) cryptographic utilities
///
/// This class implements the enhanced Gen2 protocol used by FreeStyle Libre 2 sensors in:
/// - United States (E5, E6 models)
/// - Canada
/// - Australia
///
/// **Protocol Overview:**
/// Gen2 uses whiteCryption Secure Key Box for encryption, which is more secure than Gen1 (EU sensors).
/// The protocol involves:
/// 1. NFC authentication to get session info
/// 2. BLE streaming unlock with encrypted commands
/// 3. Decryption of BLE data packets
///
/// **Implementation Status:**
/// - Structure: ✅ Complete
/// - Integration: ✅ Ready
/// - Cryptographic functions: ⚠️ Require native library (see p1/p2 functions)
///
/// **References:**
/// - Juggluco implementation: https://github.com/j-kaltes/Juggluco/commit/9ff9c9d
/// - DiaBLE Gen2 research: https://github.com/gui-dos/DiaBLE
///
/// - Note: This implementation is based on reverse engineering efforts by the community.
///         The actual cryptographic operations require either:
///         1. Native library integration (liblibre2gen2.so or similar)
///         2. Pure Swift implementation of the whiteCryption algorithm
class Libre2Gen2 {

    // MARK: - Properties

    /// Current streaming context/session ID returned by authentication
    /// This context is used for all subsequent encrypted operations
    var streamingContext: Int = 0

    /// Sensor unique identifier (UID) read from NFC
    /// 8 bytes, read from NFC tag
    var sensorUID: Data = Data()

    /// Authentication data formed during streaming setup
    /// - 10 bytes in older US2 models
    /// - 12 bytes in newer models
    /// Formed when passed as third inout argument to verifyEnableStreamingResponse()
    var streamingAuthenticationData: Data = Data()

    /// Logger for debugging
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2)


    // MARK: - Command Constants

    /// Security command to retrieve session information from sensor
    static let GEN_SECURITY_CMD_GET_SESSION_INFO      =  0x1f

    /// Decrypt BLE streaming data packets
    static let GEN2_CMD_DECRYPT_BLE_DATA              =   773

    /// Decrypt NFC data read from sensor
    static let GEN2_CMD_DECRYPT_NFC_DATA              = 12545

    /// Decrypt NFC streaming data
    static let GEN2_CMD_DECRYPT_NFC_STREAM            =  6520

    /// End secure session and cleanup
    static let GEN2_CMD_END_SESSION                   = 37400

    /// Get authentication context for command generation
    static let GEN2_CMD_GET_AUTH_CONTEXT              = 28960

    /// Generate authenticated BLE command
    static let GEN2_CMD_GET_BLE_AUTHENTICATED_CMD     =  6505

    /// Create secure session
    static let GEN2_CMD_GET_CREATE_SESSION            = 29465

    /// Generate authenticated NFC command
    static let GEN2_CMD_GET_NFC_AUTHENTICATED_CMD     =  6440

    /// Get P values for authentication
    static let GEN2_CMD_GET_PVALUES                   =  6145

    /// Initialize crypto library
    static let GEN2_CMD_INIT_LIB                      =     0

    /// Verify command response
    static let GEN2_CMD_VERIFY_RESPONSE               = 22321

    // Note: Additional command for future use
    // static let GEN2_CMD_PERFORM_SENSOR_CONTEXT_CRYPTO = 18712


    enum Gen2Error: Int, Error, CaseIterable {
        case GEN2_SEC_ERROR_INIT            = -1
        case GEN2_SEC_ERROR_CMD             = -2
        case GEN2_SEC_ERROR_KDF             = -9
        case GEN2_SEC_ERROR_RESPONSE_SIZE   = -10
        case GEN2_ERROR_AUTH_CONTEXT        = -11
        case GEN2_ERROR_PRNG_ERROR          = -12
        case GEN2_ERROR_KEY_NOT_FOUND       = -13
        case GEN2_ERROR_SKB_ERROR           = -14
        case GEN2_ERROR_INVALID_RESPONSE    = -15
        case GEN2_ERROR_INSUFFICIENT_BUFFER = -16
        case GEN2_ERROR_CRC_MISMATCH        = -17
        case GEN2_ERROR_MISSING_NATIVE      = -98
        case GEN2_ERROR_PROCESS_ERROR       = -99

        init(_ value: Int) {
            for error in Gen2Error.allCases {
                if value == error.rawValue {
                    self = error
                    return
                }
            }
            self = .GEN2_ERROR_MISSING_NATIVE
        }

        var ordinal: Int {
            switch self {
            case .GEN2_ERROR_AUTH_CONTEXT:        return 1
            case .GEN2_ERROR_KEY_NOT_FOUND:       return 2
            case .GEN2_SEC_ERROR_INIT:            return 3
            case .GEN2_SEC_ERROR_CMD:             return 4
            case .GEN2_SEC_ERROR_RESPONSE_SIZE:   return 5
            case .GEN2_ERROR_INSUFFICIENT_BUFFER: return 6
            case .GEN2_ERROR_MISSING_NATIVE:      return 7
            case .GEN2_SEC_ERROR_KDF:             return 8
            case .GEN2_ERROR_PRNG_ERROR:          return 9
            case .GEN2_ERROR_CRC_MISMATCH:        return 10
            case .GEN2_ERROR_SKB_ERROR:           return 11
            case .GEN2_ERROR_INVALID_RESPONSE:    return 12
            case .GEN2_ERROR_PROCESS_ERROR:       return 13
            }
        }

    }

    struct Result {
        let data: Data?
        let error: Gen2Error?
    }


    // MARK: - Core Cryptographic Functions
    //
    // ⚠️ IMPLEMENTATION REQUIRED ⚠️
    //
    // These functions perform the actual Gen2 encryption/decryption operations.
    // They map to Juggluco's process1() and process2() functions in liblibre2gen2.so
    //
    // **Implementation Options:**
    // 1. Native Library: Link to compiled C/C++ library (liblibre2gen2.a or .framework)
    // 2. Pure Swift: Implement whiteCryption Secure Key Box algorithm in Swift
    // 3. Third-party: Use existing implementation (requires proper licensing)
    //
    // **Function Behavior:**
    // - p1: Prepares cryptographic context and parameters
    // - p2: Performs actual encryption/decryption operation
    //
    // **Note for PR reviewers:**
    // If you have access to the Gen2 cryptographic library, implementation goes here.
    // The rest of the class is structured to work once these functions are implemented.
    //
    // References:
    // - Juggluco: https://github.com/j-kaltes/Juggluco/commit/9ff9c9d
    // - Newer versions may require additional random token array parameter

    /// Phase 1: Prepare cryptographic operation
    ///
    /// This function initializes the cryptographic context and prepares parameters
    /// for the encryption/decryption operation.
    ///
    /// - Parameters:
    ///   - command: The Gen2 command constant (e.g., GEN2_CMD_DECRYPT_BLE_DATA)
    ///   - i2: Integer parameter (context or session ID)
    ///   - d1: Optional data parameter 1 (varies by command)
    ///   - d2: Optional data parameter 2 (varies by command)
    /// - Returns: Prepared context ID (positive) or error code (negative)
    ///
    /// - Important: This is a stub that requires native library implementation
    static func p1(command: Int, _ i2: Int, _ d1: Data?, _ d2: Data?) -> Int {
        // TODO: Implement Gen2 cryptographic library call
        // Expected implementation:
        // return native_gen2_process1(command, i2, d1, d2)

        trace("⚠️ Libre2Gen2.p1() called but not implemented - Gen2 sensors will not work", log: OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2), category: ConstantsLog.categoryCGMLibre2, type: .error)
        return 0  // Return 0 to indicate no implementation
    }

    /// Phase 2: Execute cryptographic operation
    ///
    /// This function performs the actual encryption or decryption operation
    /// using the context prepared by p1().
    ///
    /// - Parameters:
    ///   - command: The Gen2 command constant
    ///   - p1: Context ID returned from p1() function
    ///   - d1: Data to encrypt/decrypt
    ///   - d2: Optional additional data parameter
    /// - Returns: Result containing encrypted/decrypted data or error
    ///
    /// - Important: This is a stub that requires native library implementation
    static func p2(command: Int, p1: Int, _ d1: Data, _ d2: Data?) -> Result {
        // TODO: Implement Gen2 cryptographic library call
        // Expected implementation:
        // let result = native_gen2_process2(command, p1, d1, d2)
        // return Result(data: result.data, error: result.error)

        trace("⚠️ Libre2Gen2.p2() called but not implemented - Gen2 sensors will not work", log: OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2), category: ConstantsLog.categoryCGMLibre2, type: .error)
        return Result(data: Data(), error: .GEN2_ERROR_MISSING_NATIVE)
    }


    // MARK: - Session Management

    /// Create a secure session with the sensor
    ///
    /// This establishes an encrypted communication session with the Gen2 sensor.
    /// Must be called after NFC authentication.
    ///
    /// - Parameters:
    ///   - context: Authentication context from previous operation
    ///   - i2: Session type (0 for NFC, 1 for BLE streaming)
    ///   - data: Session info data from sensor response
    /// - Returns: Session context (0 = success) or error code
    static func createSecureSession(context: Int, _ i2: Int, data: Data) -> Int {
        return p1(command: GEN2_CMD_GET_CREATE_SESSION, context, Data([UInt8(i2)]), data)
    }

    /// End the current secure session
    ///
    /// Cleanup and close the encrypted session. Should be called when:
    /// - Communication is complete
    /// - An error occurs
    /// - Switching sensors
    ///
    /// - Parameter context: Active session context to close
    /// - Returns: 0 on success, error code otherwise
    static func endSession(context: Int) -> Int {
        return p1(command: GEN2_CMD_END_SESSION, context, nil, nil)
    }

    // MARK: - Authenticated Commands

    /// Generate authenticated BLE command
    ///
    /// Creates an encrypted command for BLE communication with the sensor.
    /// Used for streaming unlock and other BLE operations.
    ///
    /// **Flow:**
    /// 1. Get authentication context from sensor UID
    /// 2. Generate BLE authenticated command with challenge
    /// 3. Return command data via output parameter
    ///
    /// - Parameters:
    ///   - command: Command byte (e.g., 0x1f for session info)
    ///   - uid: Sensor unique identifier (8 bytes from NFC)
    ///   - i2: Integer parameter from sensor attribute
    ///   - challenge: Challenge data from sensor
    ///   - output: Generated authenticated command (19 bytes for BLE unlock)
    /// - Returns: Authentication context (positive) or error code (negative)
    static func getNfcAuthenticatedCommandBLE(command: Int, uid: Data, i2: Int, challenge: Data, output: inout Data) -> Int {
        let authContext = p1(command: GEN2_CMD_GET_AUTH_CONTEXT, i2, uid, nil)
        if authContext < 0 {
            return authContext
        }
        let commandArg = Data([1, UInt8(command)])  // 1 = BLE mode
        let result = p2(command: GEN2_CMD_GET_BLE_AUTHENTICATED_CMD, p1: authContext, commandArg, challenge)
        if result.data == nil {
            _ = endSession(context: authContext)
            return result.error != nil ? result.error!.rawValue : Gen2Error.GEN2_ERROR_PROCESS_ERROR.rawValue
        }
        output = result.data!
        return authContext
    }

    static func getNfcAuthenticatedCommandNfc(command: Int, uid: Data, i2: Int, challenge: Data, output: inout Data) -> Int {
        let authContext = p1(command: GEN2_CMD_GET_AUTH_CONTEXT, i2, uid, nil)
        if authContext < 0 {
            return authContext
        }
        let commandArg = Data([0, UInt8(command)])
        let result = p2(command: GEN2_CMD_GET_NFC_AUTHENTICATED_CMD, p1: authContext, commandArg, challenge)
        if result.data == nil {
            _ = endSession(context: authContext)
            return result.error != nil ? result.error!.rawValue : Gen2Error.GEN2_ERROR_PROCESS_ERROR.rawValue
        }
        output = result.data!
        let manufacturerCode = !uid.isEmpty ? uid[6] : 0x07
        output[0 ... 3] = Data([2, 0xA1, manufacturerCode, UInt8(command)])
        return authContext
    }


#if !os(watchOS)

    static func getAuthenticatedCommand(sensorUID: Data, attribute: Data, challenge: Data, command: Int, output: inout Data) -> Int {
        if attribute.count == 0 {
            return -1
        }
        let i = Int(UInt16(attribute[2...3]))
        if challenge.count == 0 {
            return -1
        }
        return getNfcAuthenticatedCommandNfc(command: command, uid: sensorUID, i2: i, challenge: challenge, output: &output)
    }

#endif


    static func decrytpNfcData(context: Int, fromBlock: Int, count: Int, data: Data) -> Result {
        return p2(command: GEN2_CMD_DECRYPT_NFC_STREAM, p1: context, Data([UInt8(fromBlock), UInt8(count)]), data)
    }


    func createSecureStreamingSession(data: Data) -> Int {
        if Libre2Gen2.createSecureSession(context: streamingContext, 1, data: data) != 0 {
            _ = Libre2Gen2.endSession(context: streamingContext)
            streamingContext = 0
        }
        return streamingContext
    }


    // TODO:
    func getStreamingUnlockPayload(challenge: Data) -> Data {
        if streamingContext > 0 {
            _ = Libre2Gen2.endSession(context: streamingContext)
        }
        var i = 0
        var payload = Data(count: 19)
        do {
            if streamingAuthenticationData.count == 12 {
                i = Int(UInt16(streamingAuthenticationData[10...11]))
            } else if streamingAuthenticationData.count < 10 {
                throw Gen2Error.GEN2_ERROR_INSUFFICIENT_BUFFER // "unexpected auth data size"
            } else {
                i = -1
            }
            let extendedChallenge = streamingAuthenticationData.prefix(10) + challenge
            streamingContext = Libre2Gen2.getNfcAuthenticatedCommandBLE(command: Libre2Gen2.GEN_SECURITY_CMD_GET_SESSION_INFO, uid: sensorUID, i2: i, challenge: extendedChallenge, output: &payload)
        } catch {
            // Error handling
        }
        return payload
    }


    static func verifyCommandResponse(context: Int, _ i2: Int, challenge: Data, output: inout Data) -> Int {
        let commandArg = Data([UInt8(i2), UInt8(output.count)])
        let result = p2(command: GEN2_CMD_VERIFY_RESPONSE, p1: context, commandArg, challenge)
        if result.data == nil {
            _ = endSession(context: context)
            return result.error != nil ? result.error!.rawValue : Gen2Error.GEN2_ERROR_PROCESS_ERROR.rawValue
        }
        output = result.data!
        return output.count
    }


    // TODO: newer version returns a Boolean and passes 9 as arg
    static func verifyEnableStreamingResponse(context: Int, challenge: Data, authenticationData: inout Data, output: inout Data) -> Int {
        var verifyOutput = Data(count: 9)
        let verify = verifyCommandResponse(context: context, 0, challenge: challenge, output: &verifyOutput)
        if verify < 0 {
            return verify
        }
        let commandArg = Data([7])
        let result = p2(command: GEN2_CMD_GET_PVALUES, p1: context, commandArg, nil)
        if result.data == nil {
            _ = endSession(context: context)
            return result.error != nil ? result.error!.rawValue : Gen2Error.GEN2_ERROR_PROCESS_ERROR.rawValue
        }
        // join the 7 bytes of GET_PVALUES result.data and the last 3 bytes of 9 of verifyOutput
        authenticationData[0 ..< result.data!.count] = result.data!
        authenticationData[result.data!.count ..< result.data!.count + 3] = verifyOutput[6 ... 8]
        // copy the first 6 bytes of 9 of verifyOutput in the second array `output` passed by reference
        output[0 ..< 6] = Data(verifyOutput.prefix(6))
        return 0
    }


    // MARK: - Data Decryption

    /// Decrypt BLE streaming data
    ///
    /// Decrypts glucose data received via BLE from Gen2 sensor.
    ///
    /// **Usage:**
    /// ```swift
    /// let result = Libre2Gen2.decryptStreamingData(context: streamingContext, data: encryptedData)
    /// if let decryptedData = result.data {
    ///     // Process decrypted glucose data
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - context: Active streaming context from session creation
    ///   - data: Encrypted BLE data (46 bytes from sensor)
    /// - Returns: Result with decrypted data or error
    static func decryptStreamingData(context: Int, data: Data) -> Result {
        return p2(command: GEN2_CMD_DECRYPT_BLE_DATA, p1: context, data, nil)
    }


    // MARK: - Utility Functions

    /// Check if a sensor type is Gen2
    ///
    /// Determines if a LibreSensorType requires Gen2 encryption.
    ///
    /// - Parameter sensorType: The sensor type to check
    /// - Returns: true if Gen2 (US/CA/AU/RU), false if Gen1 (EU/LATAM)
    static func isGen2Sensor(_ sensorType: LibreSensorType) -> Bool {
        switch sensorType {
        case .libreUS, .libreUSE6:
            return true  // Gen2 sensors (US/CA/AU)
        case .libre22B:
            // 2B could be either LATAM (Gen1) or RU (Gen2)
            // Need full patch info to determine - see isGen2Sensor(patchInfo:)
            return false  // Default to Gen1 when type alone is insufficient
        default:
            return false  // Gen1 or other sensors
        }
    }

    /// Check if sensor patch info indicates Gen2
    ///
    /// Uses the full patch info to determine Gen2 status, including:
    /// - E5/E6: US/CA/AU Gen2 sensors
    /// - 2B 0A 39 08: Russian Libre 2 Gen2
    /// - 2B 0A 3A 08: LATAM Libre 2 Plus (Gen1, not Gen2)
    ///
    /// - Parameter patchInfo: Full patch info string from NFC (at least first 8 hex chars)
    /// - Returns: true if Gen2 sensor
    static func isGen2Sensor(patchInfo: String) -> Bool {
        let normalized = patchInfo.uppercased().replacingOccurrences(of: " ", with: "")

        // E5 and E6 are Gen2 US/CA/AU sensors
        if normalized.hasPrefix("E5") || normalized.hasPrefix("E6") {
            return true
        }

        // Check for Russian Gen2: 2B 0A 39 08
        if LibreSensorType.isRussianGen2(patchInfo: patchInfo) {
            return true
        }

        return false
    }


}
