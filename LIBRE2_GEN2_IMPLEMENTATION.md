# Libre 2 Gen2 (US/CA/AU/RU) Implementation Guide

## Overview

This document describes the implementation of support for FreeStyle Libre 2 Gen2 sensors in xDripSwift:
- **US/CA/AU**: Models E5, E6
- **Russia**: Model 2B (14-day, Gen2 variant)
- **Latin America**: Model 2B (14-day Plus, Gen1 variant)

**Status:** 🟡 Structure Complete - Awaiting Cryptographic Implementation

## What's Implemented ✅

### 1. Core Structure (`Libre2Gen2.swift`)
- ✅ Complete Gen2 protocol structure
- ✅ Command constants for all operations
- ✅ Error handling with `Gen2Error` enum
- ✅ Session management functions
- ✅ Authenticated command generation
- ✅ Data decryption framework
- ✅ Utility functions for Gen2 detection
- ✅ Comprehensive documentation

### 2. Integration (`CGMLibre2Transmitter.swift`)
- ✅ Automatic Gen2 sensor detection via patch info
- ✅ `Libre2Gen2` instance initialization for Gen2 sensors
- ✅ Conditional decryption path (Gen1 vs Gen2)
- ✅ Error handling and user feedback
- ✅ Logging for debugging

### 3. Detection (`LibreSensorType`)
- ✅ Utility functions to identify Gen2 sensors
- ✅ Support for `.libreUS` (E5) and `.libreUSE6` (E6) types
- ✅ Support for `.libre22B` (2B) type with regional detection:
  - LATAM Libre 2 Plus: `2B 0A 3A 08` (Gen1 - uses PreLibre2 decryption)
  - RU Libre 2: `2B 0A 39 08` (Gen2 - requires whiteCryption)
- ✅ Helper functions: `isRussianGen2()` and `isLatinAmericanPlus()`

## What's Missing ⚠️

### Core Cryptographic Functions

The following two functions in `Libre2Gen2.swift` require implementation:

```swift
static func p1(command: Int, _ i2: Int, _ d1: Data?, _ d2: Data?) -> Int
static func p2(command: Int, p1: Int, _ d1: Data, _ d2: Data?) -> Result
```

These functions perform the actual Gen2 encryption/decryption using the **whiteCryption Secure Key Box** algorithm.

#### Location
- File: `xDrip/BluetoothTransmitter/CGM/Libre/Utilities/Libre2Gen2.swift`
- Lines: ~187-217
- Marked with: `// ⚠️ IMPLEMENTATION REQUIRED ⚠️`

## Implementation Options

### Option 1: Native Library Integration (Recommended)

If you have access to the Gen2 cryptographic library (e.g., from Juggluco or Abbott sources):

1. **Add the native library to the project:**
   - `liblibre2gen2.a` or `liblibre2gen2.framework`
   - Ensure it supports iOS architectures (arm64)

2. **Create a bridging header** (`Libre2Gen2-Bridging-Header.h`):
   ```objc
   #ifndef Libre2Gen2_Bridging_Header_h
   #define Libre2Gen2_Bridging_Header_h

   // Declare the native functions
   int native_gen2_process1(int command, int i2, const void* d1, int d1_len, const void* d2, int d2_len);
   int native_gen2_process2(int command, int p1, const void* d1, int d1_len, const void* d2, int d2_len, void* output, int* output_len);

   #endif
   ```

3. **Implement the Swift wrappers:**
   ```swift
   static func p1(command: Int, _ i2: Int, _ d1: Data?, _ d2: Data?) -> Int {
       let d1Ptr = d1?.withUnsafeBytes { $0.baseAddress }
       let d2Ptr = d2?.withUnsafeBytes { $0.baseAddress }
       return Int(native_gen2_process1(Int32(command), Int32(i2),
                                       d1Ptr, Int32(d1?.count ?? 0),
                                       d2Ptr, Int32(d2?.count ?? 0)))
   }

   static func p2(command: Int, p1: Int, _ d1: Data, _ d2: Data?) -> Result {
       var outputBuffer = [UInt8](repeating: 0, count: 1024)
       var outputLen: Int32 = 1024

       let result = d1.withUnsafeBytes { d1Ptr in
           let d2Ptr = d2?.withUnsafeBytes { $0.baseAddress }
           return native_gen2_process2(Int32(command), Int32(p1),
                                      d1Ptr.baseAddress, Int32(d1.count),
                                      d2Ptr, Int32(d2?.count ?? 0),
                                      &outputBuffer, &outputLen)
       }

       if result < 0 {
           return Result(data: nil, error: Gen2Error(result))
       }

       return Result(data: Data(outputBuffer.prefix(Int(outputLen))), error: nil)
   }
   ```

4. **Link the library in Xcode:**
   - Add the library to "Link Binary With Libraries"
   - Set the bridging header path in Build Settings

### Option 2: Pure Swift Implementation

If you have documentation or reverse-engineered the whiteCryption algorithm:

1. Implement the cryptographic algorithm in Swift
2. Replace the stub functions with your implementation
3. Ensure compatibility with the protocol expectations

### Option 3: Use Existing Open Source (If Available)

Check if any compatible implementations exist in:
- Juggluco updates
- DiaBLE project
- Community contributions

## Testing

Once the cryptographic functions are implemented:

### Unit Tests
1. Test Gen2 sensor detection
2. Test session creation and management
3. Test authenticated command generation
4. Test data decryption with known test vectors

### Integration Tests
1. Scan a US/CA Gen2 sensor with NFC
2. Verify sensor type detection
3. Enable BLE streaming
4. Verify glucose data decryption
5. Confirm readings match LibreLink app

## Expected Behavior

### With Implementation Complete:
1. NFC scan detects Gen2 sensor (E5/E6)
2. Log shows: "Gen2 sensor detected (US/CA/AU)"
3. BLE streaming starts successfully
4. Data decrypts correctly
5. Glucose readings display in app

### Without Implementation (Current State):
1. NFC scan detects Gen2 sensor
2. Log shows: "Gen2 sensor detected"
3. BLE connection succeeds
4. Decryption fails with error
5. User sees: "Gen2 sensor detected but decryption not available"

## Code References

### Key Files Modified:
1. **`xDrip/BluetoothTransmitter/CGM/Libre/Utilities/Libre2Gen2.swift`**
   - New file
   - Complete Gen2 protocol implementation
   - Lines 187-217: Crypto functions needing implementation

2. **`xDrip/BluetoothTransmitter/CGM/Libre/Libre2/CGMLibre2Transmitter.swift`**
   - Line 64-66: Added `libre2Gen2` property
   - Line 384-400: Gen2 sensor detection and initialization
   - Line 291-322: Conditional decryption (Gen1 vs Gen2)

### Utility Functions:
```swift
// Check if sensor is Gen2
Libre2Gen2.isGen2Sensor(_ sensorType: LibreSensorType) -> Bool
Libre2Gen2.isGen2Sensor(patchInfo: String) -> Bool
```

## Community References

### Research & Documentation:
- **Juggluco:** https://github.com/j-kaltes/Juggluco
  - Uses native library from Abbott APK
  - `process1()` and `process2()` wrappers

- **DiaBLE:** https://github.com/gui-dos/DiaBLE
  - Gen2 protocol research
  - Libre3 encryption (similar to Gen2)

- **Protocol Analysis:** https://protocols.glucometers.tech/abbott/freestyle-libre-2.html
  - Encryption details
  - Message structure

- **Flameeyes Blog:** https://flameeyes.blog/2020/01/30/freestyle-libre-2-encrypted-protocol-notes/
  - Reverse engineering notes
  - Key derivation details

## Patch Info Reference

The patch info is a 4-byte identifier read from the sensor via NFC. Format: `[Type][Variant][Generation][Region]`

### Known Patch Info Values:

| Sensor Type | Patch Info | Generation | Notes |
|-------------|------------|------------|-------|
| **Libre 2+ EU** | `C6 09 31 01` | Gen1 | 15-day |
| **Libre 2+ EU** | `7F 0E 31 01` | Gen1 | 15-day (newer) |
| **Libre 2 EU** | `7F 0E 30 01` | Gen1 | 14-day |
| **Libre 2+ US** | `2C 0A 3A 02` | Gen2 | Uses whiteCryption |
| **Libre 2+ LA** | `2B 0A 3A 08` | Gen1 | LATAM Plus, 14-day |
| **Libre 2 RU** | `2B 0A 39 08` | Gen2 | Russian, 14-day, uses whiteCryption |

### Detection Logic:
- **First byte (2B)**: Both LATAM and RU sensors
- **Third byte**: Distinguishes variants
  - `3A` = LATAM (Gen1 encryption)
  - `39` = Russian (Gen2 encryption)
- **Last byte (08)**: Common region code for both

## Security Considerations

- Gen2 uses **whiteCryption Secure Key Box** (proprietary)
- More secure than Gen1 (EU sensors)
- Requires proper key management
- Challenge-response authentication
- Session-based encryption
- **LATAM sensors use Gen1 encryption** (PreLibre2 algorithm)
- **Russian sensors require Gen2 encryption** (whiteCryption, not yet implemented)

## License & Legal

This implementation is based on community reverse engineering efforts. Ensure compliance with:
- Local regulations
- Abbott's terms of service
- Cryptographic export restrictions

## Questions?

For implementation questions or if you have access to the Gen2 cryptographic library:
- Open an issue on GitHub
- Contact the xDripSwift maintainers
- Reference this document in discussions

---

**Last Updated:** 2025-12-04
**Status:** Awaiting cryptographic implementation (p1/p2 functions)
**Contact:** See xDripSwift repository
