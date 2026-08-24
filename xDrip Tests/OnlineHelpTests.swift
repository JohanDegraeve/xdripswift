//
//  OnlineHelpTests.swift
//  xdripTests
//
//  Created by Paul Plant on 14/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class OnlineHelpTests: XCTestCase {
    func testEveryTopicBuildsItsExactFutureDocumentationURL() {
        let expectations: [(OnlineHelpTopic, String)] = [
            (.settings, "use/settings/"),
            (.glucoseDisplay, "use/glucoseDisplay/"),
            (.alertsAndNotifications, "use/alertsAndNotifications/"),
            (.dataManagement, "use/dataManagement/"),
            (.issueReporting, "troubleshoot/reportingIssues/"),
            (.activityLog, "troubleshoot/activityLog/"),
            (.nightscoutService, "services/nightscout/"),
            (.dexcomShareService, "services/dexcomShare/"),
            (.appleHealth, "services/appleHealth/"),
            (.calendarShare, "services/calendarShare/"),
            (.contactImage, "display/contactImage/"),
            (.osAidShare, "services/osAidShare/"),
            (.speakGlucose, "display/speakGlucose/"),
            (.snooze, "use/snooze/"),
            (.glucoseReadings, "use/glucoseReadings/"),
            (.sensorManagement, "use/sensor/"),
            (.calibration, "use/sensor/#when-calibration-is-available"),
            (.glucoseAdjustments, "use/glucoseAdjustments/"),
            (.quickShowHide, "use/quickShowHide/"),
            (.treatments, "use/treatments/"),
            (.statistics, "use/statistics/"),
            (.devices, "use/devices/"),
            (.addDirectCGM, "connect/cgm/"),
            (.dexcomG5G6One, "connect/dexcomG5G6One/"),
            (.dexcomG7OnePlusStelo, "connect/dexcomG7OnePlusStelo/"),
            (.libre2, "connect/libre2/"),
            (.libreTransmitters, "connect/libreTransmitters/"),
            (.medtrumNano, "connect/medtrum/"),
            (.followerHeartbeat, "connect/followerHeartbeat/"),
            (.m5Stack, "connect/devices/"),
            (.nightscoutFollower, "connect/nightscoutFollower/"),
            (.libreLinkUpFollower, "connect/libreLinkUp/"),
            (.dexcomShareFollower, "connect/dexcomShareFollower/"),
            (.sharedCalendarFollower, "connect/sharedCalendar/"),
            (.careLinkFollower, "connect/careLink/"),
            (.medtrumEasyViewFollower, "connect/medtrumEasyView/")
        ]

        XCTAssertEqual(expectations.count, OnlineHelpTopic.allCases.count)

        for (topic, expectedSuffix) in expectations {
            let url = OnlineHelp.url(for: topic, languageIdentifier: "en", translate: true)
            XCTAssertEqual(
                url?.absoluteString,
                "https://xdrip4ios.readthedocs.io/en/latest/" + expectedSuffix,
                "Unexpected URL for \(topic)"
            )
        }
    }

    func testNonEnglishAppLanguageBuildsTranslatedURL() {
        let url = OnlineHelp.url(
            for: .calibration,
            languageIdentifier: "fr-FR",
            translate: true
        )

        XCTAssertEqual(url?.host, "xdrip4ios-readthedocs-io.translate.goog")
        XCTAssertEqual(url?.path, "/en/latest/use/sensor")
        XCTAssertEqual(url?.fragment, "when-calibration-is-available")

        let items = URLComponents(url: tryUnwrap(url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first(where: { $0.name == "_x_tr_sl" })?.value, "auto")
        XCTAssertEqual(items?.first(where: { $0.name == "_x_tr_tl" })?.value, "fr")
        XCTAssertEqual(items?.first(where: { $0.name == "_x_tr_hl" })?.value, "fr")
        XCTAssertEqual(items?.first(where: { $0.name == "_x_tr_pto" })?.value, "nui")
    }

    func testTranslationDisabledAlwaysUsesDirectURL() {
        let url = OnlineHelp.url(
            for: .careLinkFollower,
            languageIdentifier: "es-ES",
            translate: false
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://xdrip4ios.readthedocs.io/en/latest/connect/careLink/"
        )
    }

    func testMissingLanguageUsesDirectURL() {
        let url = OnlineHelp.url(for: .settings, languageIdentifier: nil, translate: true)
        XCTAssertEqual(
            url?.absoluteString,
            "https://xdrip4ios.readthedocs.io/en/latest/use/settings/"
        )
    }

    func testAppLanguageIdentifiersNormalizeToGoogleLanguageCodes() {
        XCTAssertEqual(OnlineHelp.normalizedLanguageCode(from: "pt-PT"), "pt")
        XCTAssertEqual(OnlineHelp.normalizedLanguageCode(from: "pl-PL"), "pl")
        XCTAssertEqual(OnlineHelp.normalizedLanguageCode(from: "zh-Hans"), "zh")
        XCTAssertNil(OnlineHelp.normalizedLanguageCode(from: nil))
    }

    @MainActor
    func testOpenPassesTheBuiltURLToTheInjectedOpenerOnce() {
        var openedURLs: [URL] = []

        OnlineHelp.open(
            .statistics,
            languageIdentifier: "es",
            translate: true,
            using: { openedURLs.append($0) }
        )

        XCTAssertEqual(openedURLs.count, 1)
        XCTAssertEqual(openedURLs.first?.host, "xdrip4ios-readthedocs-io.translate.goog")
        XCTAssertEqual(openedURLs.first?.path, "/en/latest/use/statistics")
    }

    func testFollowerSourcesHaveExhaustiveTopics() {
        XCTAssertEqual(FollowerDataSourceType.nightscout.onlineHelpTopic, .nightscoutFollower)
        XCTAssertEqual(FollowerDataSourceType.libreLinkUp.onlineHelpTopic, .libreLinkUpFollower)
        XCTAssertEqual(FollowerDataSourceType.libreLinkUpRussia.onlineHelpTopic, .libreLinkUpFollower)
        XCTAssertEqual(FollowerDataSourceType.dexcomShare.onlineHelpTopic, .dexcomShareFollower)
        XCTAssertEqual(FollowerDataSourceType.medtrumEasyView.onlineHelpTopic, .medtrumEasyViewFollower)
        XCTAssertEqual(FollowerDataSourceType.calendar.onlineHelpTopic, .sharedCalendarFollower)
        XCTAssertEqual(FollowerDataSourceType.careLink.onlineHelpTopic, .careLinkFollower)
    }

    func testBluetoothPeripheralTypesHaveExactTopics() {
        XCTAssertEqual(BluetoothPeripheralType.M5StackType.onlineHelpTopic, .m5Stack)
        XCTAssertEqual(BluetoothPeripheralType.M5StickCType.onlineHelpTopic, .m5Stack)
        XCTAssertEqual(BluetoothPeripheralType.Libre2Type.onlineHelpTopic, .libre2)
        XCTAssertEqual(BluetoothPeripheralType.MiaoMiaoType.onlineHelpTopic, .libreTransmitters)
        XCTAssertEqual(BluetoothPeripheralType.BubbleType.onlineHelpTopic, .libreTransmitters)
        XCTAssertEqual(BluetoothPeripheralType.DexcomType.onlineHelpTopic, .dexcomG5G6One)
        XCTAssertEqual(BluetoothPeripheralType.DexcomG7Type.onlineHelpTopic, .dexcomG7OnePlusStelo)
        XCTAssertEqual(BluetoothPeripheralType.Libre3HeartBeatType.onlineHelpTopic, .followerHeartbeat)
        XCTAssertEqual(BluetoothPeripheralType.DexcomG7HeartBeatType.onlineHelpTopic, .followerHeartbeat)
        XCTAssertEqual(BluetoothPeripheralType.OmniPodHeartBeatType.onlineHelpTopic, .followerHeartbeat)
        XCTAssertEqual(BluetoothPeripheralType.MedtrumTouchCareNanoType.onlineHelpTopic, .medtrumNano)
    }

    func testBluetoothPeripheralCategoriesHaveExactTopics() {
        XCTAssertEqual(BluetoothPeripheralCategory.CGM.onlineHelpTopic, .addDirectCGM)
        XCTAssertEqual(BluetoothPeripheralCategory.M5Stack.onlineHelpTopic, .m5Stack)
        XCTAssertEqual(BluetoothPeripheralCategory.HeartBeat.onlineHelpTopic, .followerHeartbeat)
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}
