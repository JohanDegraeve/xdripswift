//
//  AuthRequestTxMessage.swift
//  xDrip5
//
//  Created by Nathan Racklyeft on 11/22/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation

/// The Dexcom display role requested in the final byte of an authentication request.
///
/// G6 uses the same BLE service and characteristics for both roles. The slot is selected by this
/// protocol byte, not by scanning for a different service UUID. Slot 2 is the established mobile
/// default. Slot 1 is normally reserved for a receiver or compatible pump.
///
/// xDrip+ defines these values as `endByteStd` (`0x02`) and `endByteAlt` (`0x01`):
/// https://github.com/NightscoutFoundation/xDrip/blob/f3022645933fe0f524566aebed604174cdc1a388/app/src/main/java/com/eveningoutpost/dexdrip/g5model/AuthRequestTxMessage.java#L18-L26
/// Device testing has also confirmed `0x03` as an Anubis-only third slot.
protocol DexcomBluetoothSlotValue: RawRepresentable where RawValue == UInt8 {
    static var defaultSlot: Self { get }
}

enum DexcomG6BluetoothSlot: UInt8, CaseIterable, DexcomBluetoothSlotValue {
    case mobileApp = 0x2
    case medicalDevice = 0x1
    case anubisExperimental = 0x3

    static let defaultSlot: DexcomG6BluetoothSlot = .mobileApp

    /// Slot 3 is implemented by Anubis firmware but is not valid for standard Dexcom transmitters.
    func normalized(isAnubis: Bool) -> DexcomG6BluetoothSlot {
        self == .anubisExperimental && !isAnubis ? .defaultSlot : self
    }
}

/// The display role requested in the final byte of a primary G7 authentication request.
enum DexcomG7BluetoothSlot: UInt8, CaseIterable, DexcomBluetoothSlotValue {
    /// The normal phone application identity and the default used by xDrip4iOS.
    case mobileApp = 0x2

    /// The identity intended for a Dexcom receiver or compatible pump.
    case medicalDevice = 0x1

    /// The independent identity intended for a directly connected smart watch.
    case smartWatch = 0x3

    /// Keeps restored or newly created G7 configuration on the validated mobile-app channel.
    static let defaultSlot: DexcomG7BluetoothSlot = .mobileApp
}

struct AuthRequestTxMessage: TransmitterTxMessage {
    let singleUseToken: Data
    let slot: DexcomG6BluetoothSlot

    init(slot: DexcomG6BluetoothSlot = .defaultSlot) {
        let uuid = UUID().uuid

        self.slot = slot
        singleUseToken = Data([uuid.0, uuid.1, uuid.2, uuid.3,
                                      uuid.4, uuid.5, uuid.6, uuid.7])
    }

    var data: Data {
        var data = Data(for: .authRequestTx)
        data.append(singleUseToken)
        data.append(slot.rawValue)
        return data
    }
}
