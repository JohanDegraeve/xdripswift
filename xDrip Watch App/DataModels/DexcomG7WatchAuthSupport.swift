//
//  DexcomG7WatchAuthSupport.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 13/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreBluetooth
import Foundation
import os

// The shared G7 authentication code only needs these Watch-specific logging adapters.
// Message types and Bluetooth slots are compiled from the same files as the phone.
enum ConstantsLog {
    static let subSystem = "com.xdrip.watch"
    static let categoryCGMG7 = "DirectWatchG7"
}

func trace(_ message: StaticString, log: OSLog, category: String, type: OSLogType, _ args: CVarArg...) {
    // The shared auth code uses public OSLog format specifiers. Format its arguments here:
    // logging only the StaticString would lose the opcode, phase and failure details.
    let format = String(describing: message).replacingOccurrences(of: "%{public}", with: "%")
    let detail = String(format: format, arguments: args)
    os_log("G7 Watch auth: %{public}@", log: log, type: type, detail)
}

extension Data {
    func hexEncodedString() -> String { map { String(format: "%02x", $0) }.joined() }
}

struct TroubleshootingDexcomBluetoothChannel {
    let name: String
    init(_ slot: DexcomG7BluetoothSlot) { name = "Slot \(slot.rawValue)" }
}
