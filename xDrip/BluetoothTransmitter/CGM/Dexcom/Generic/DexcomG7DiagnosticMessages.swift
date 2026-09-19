import Foundation

/// Decodes the battery information returned by a Dexcom G7-family sensor.
///
/// G5 and G6 reply to a `0x22` request with opcode `0x23`. G7, ONE+, and Stelo instead reuse
/// `0x22` for the response. The field layout remains compatible, but the different opcode and the
/// absence of the normal G6 response CRC mean that the existing `BatteryStatusRxMessage` must not
/// be relaxed for both protocols.
///
/// Reference implementation:
/// https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/g5model/BatteryInfoRxMessage.java
struct DexcomG7BatteryStatusMessage: Equatable {
    static let opCode = DexcomTransmitterOpCode.batteryStatusTx.rawValue

    /// Raw protocol result byte. It is retained for tracing because field evidence is still limited.
    let status: UInt8
    /// First battery voltage channel in 10 mV units.
    let voltageA: Int
    /// Second battery voltage channel in 10 mV units and the source of the displayed battery state.
    let voltageB: Int
    /// Internal resistance value reported by the sensor beside both voltage channels.
    let resistance: Int
    /// Sensor runtime counter. The protocol unit is retained unchanged until it is confirmed.
    let runtime: Int
    /// Signed internal temperature value. The protocol unit is retained unchanged until confirmed.
    let temperature: Int

    init?(data: Data) {
        // Ten bytes contain every field understood by xDrip4iOS. Some G7-family responses append
        // additional bytes, so accept a longer packet without assigning meaning to unknown data.
        guard data.count >= 10, data.first == Self.opCode else { return nil }

        status = data[1]
        voltageA = Int(Self.uint16(data, at: 2))
        voltageB = Int(Self.uint16(data, at: 4))
        resistance = Int(Self.uint16(data, at: 6))
        runtime = Int(data[8])
        temperature = Int(Int8(bitPattern: data[9]))
    }

    private static func uint16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }
}

/// Decodes the full version record returned by a Dexcom G7-family sensor.
///
/// The request is the normal CRC-framed `0x4A` command used by xDrip+. G7 differs from G6 by
/// returning `0x4A` again instead of `0x4B`, and the returned packet does not include the normal
/// G6 CRC. Keep this decoder separate so the strict G6 parser remains unchanged.
///
/// Reference implementations:
/// https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/g5model/VersionRequest1RxMessage.java
/// https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/g5model/VersionRequestTxMessage.java
struct DexcomG7VersionMessage: Equatable {
    static let opCode = DexcomTransmitterOpCode.transmitterVersionTx.rawValue

    /// Raw protocol result byte returned before the version fields.
    let status: UInt8
    /// Four firmware bytes formatted as the human-readable dotted value used in the device view.
    let firmwareVersion: String
    /// Little-endian build identifier retained for developer diagnostics.
    let buildVersion: UInt32
    /// Little-endian compatibility version code shown in the device view.
    let versionCode: UInt32
    /// Six-byte sensor serial returned by Bluetooth for comparison with the scanned applicator.
    let serialNumber: UInt64

    init?(data: Data) {
        // The complete known response is 20 bytes. Longer future responses may add fields after
        // the six-byte serial number, so require the known prefix rather than an exact length.
        guard data.count >= 20, data.first == Self.opCode else { return nil }

        status = data[1]
        firmwareVersion = data[2 ..< 6].map { String(Int($0)) }.joined(separator: ".")
        buildVersion = Self.uint32(data, at: 6)
        versionCode = Self.uint32(data, at: 10)
        serialNumber = Self.uint48(data, at: 14)
    }

    private static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    /// Dexcom sends the serial as six little-endian bytes rather than as a textual identifier.
    private static func uint48(_ data: Data, at offset: Int) -> UInt64 {
        (0 ..< 6).reduce(UInt64(0)) { result, index in
            result | UInt64(data[offset + index]) << UInt64(index * 8)
        }
    }
}
