//
//  DexcomG6BluetoothSlotTests.swift
//  xdripTests
//
//  Created by Paul Plant on 25/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class DexcomG6BluetoothSlotTests: XCTestCase {
    private final class SlotStore: DexcomBluetoothSlotPersisting {
        var bluetoothSlot: NSNumber?
    }

    func testAuthenticationRequestUsesMobileSlotByDefault() {
        let request = AuthRequestTxMessage()

        XCTAssertEqual(request.data.count, 10)
        XCTAssertEqual(request.data.first, DexcomTransmitterOpCode.authRequestTx.rawValue)
        XCTAssertEqual(request.data.last, DexcomG6BluetoothSlot.mobileApp.rawValue)
    }

    func testAuthenticationRequestCanUseMedicalDeviceSlot() {
        let request = AuthRequestTxMessage(slot: .medicalDevice)

        XCTAssertEqual(request.data.last, DexcomG6BluetoothSlot.medicalDevice.rawValue)
    }

    func testAuthenticationRequestCanUseAnubisSlot() {
        XCTAssertEqual(
            AuthRequestTxMessage(slot: .anubisExperimental).data.last,
            UInt8(0x03)
        )
    }

    func testAnubisSlotFallsBackToMobileAppForStandardTransmitters() {
        XCTAssertEqual(
            DexcomG6BluetoothSlot.anubisExperimental.normalized(isAnubis: true),
            .anubisExperimental
        )
        XCTAssertEqual(
            DexcomG6BluetoothSlot.anubisExperimental.normalized(isAnubis: false),
            .mobileApp
        )
    }

    func testMissingStoredSlotIsMaterializedAsFamilyDefault() {
        let store = SlotStore()

        XCTAssertEqual(store.resolvedBluetoothSlot(as: DexcomG6BluetoothSlot.self), .mobileApp)
        XCTAssertEqual(store.bluetoothSlot?.uint8Value, DexcomG6BluetoothSlot.defaultSlot.rawValue)
    }

    func testEffectiveSlotUsesFamilyDefaultWithoutChangingStorage() {
        let store = SlotStore()

        XCTAssertEqual(store.effectiveBluetoothSlot(as: DexcomG6BluetoothSlot.self), .mobileApp)
        XCTAssertNil(store.bluetoothSlot)
    }

    func testSlotSelectionIsStoredExplicitly() {
        let store = SlotStore()

        store.setBluetoothSlot(DexcomG6BluetoothSlot.medicalDevice)

        XCTAssertEqual(store.resolvedBluetoothSlot(as: DexcomG6BluetoothSlot.self), .medicalDevice)
        XCTAssertEqual(store.bluetoothSlot?.uint8Value, DexcomG6BluetoothSlot.medicalDevice.rawValue)
    }

    func testInvalidStoredSlotIsRepairedToFamilyDefault() {
        let store = SlotStore()
        store.bluetoothSlot = NSNumber(value: 258)

        XCTAssertEqual(store.resolvedBluetoothSlot(as: DexcomG6BluetoothSlot.self), .mobileApp)
        XCTAssertEqual(store.bluetoothSlot?.uint8Value, DexcomG6BluetoothSlot.defaultSlot.rawValue)
    }
}
