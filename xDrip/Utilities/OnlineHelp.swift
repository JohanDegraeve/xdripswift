//
//  OnlineHelp.swift
//  xdrip
//
//  Created by Paul Plant on 14/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Integration overview

/// A stable destination in the online xDrip4iOS documentation.
///
/// Views declare a topic rather than constructing a URL. Keeping the documentation paths here
/// gives the app one place to update when a page moves, and ensures every caller applies the same
/// translation preference.
///
/// To add help to a normal SwiftUI screen, attach `onlineHelp(_:)` to the view that owns the
/// navigation toolbar:
///
/// ```swift
/// StatisticsView()
///     .onlineHelp(.statistics)
/// ```
///
/// If the screen already builds its own toolbar, put `OnlineHelpButton` in that toolbar instead.
/// Place it before editing, adding, deleting, or other action buttons so help has a consistent
/// position:
///
/// ```swift
/// ToolbarItemGroup(placement: .navigationBarTrailing) {
///     OnlineHelpButton(topic: .calibration)
///     Button("Add") { addCalibration() }
/// }
/// ```
///
/// Settings screens created through `SettingsScreen` should pass the topic to the model. The
/// shared Settings destination supplies the toolbar button:
///
/// ```swift
/// SettingsScreen(
///     title: "CareLink",
///     onlineHelpTopic: .careLinkFollower
/// ) { presenter in
///     // Settings rows
/// }
/// ```
///
/// A custom header that does not use a navigation toolbar can render `OnlineHelpButton` directly
/// and apply any layout-specific sizing around it.
///
/// When adding a new topic:
///
/// 1. Add a semantic case below.
/// 2. Map it to the exact, case-sensitive future MkDocs path in `relativePath`.
/// 3. Add a `fragment` only when the help should open at a particular heading.
/// 4. Add the mapping to `OnlineHelpTests` and verify the documentation with a strict MkDocs build.
///
/// Topic names describe app features, not individual views. Reuse an existing topic whenever
/// multiple screens should open the same documentation page.
enum OnlineHelpTopic: CaseIterable, Hashable {
    // Settings and general app features
    case settings
    case glucoseDisplay
    case alertsAndNotifications
    case dataManagement
    case issueReporting
    case activityLog

    // Services configured from Settings
    case nightscoutService
    case dexcomShareService
    case appleHealth
    case calendarShare
    case contactImage
    case osAidShare
    case speakGlucose

    // Day-to-day feature screens
    case snooze
    case glucoseReadings
    case sensorManagement
    case calibration
    case glucoseAdjustments
    case quickShowHide
    case treatments
    case statistics
    case devices

    // Direct CGM and companion-device setup
    case addDirectCGM
    case dexcomG5G6One
    case dexcomG7OnePlusStelo
    case libre2
    case libreTransmitters
    case medtrumNano
    case followerHeartbeat
    case m5Stack

    // Follower setup
    case nightscoutFollower
    case libreLinkUpFollower
    case dexcomShareFollower
    case sharedCalendarFollower
    case careLinkFollower
    case medtrumEasyViewFollower

    /// The case-sensitive documentation path relative to `/en/latest/`.
    ///
    /// Paths deliberately end in `/` because Read the Docs serves these pages as directories.
    /// Do not include a leading slash, host, language prefix, query string, or heading fragment.
    var relativePath: String {
        switch self {
        case .settings:
            return "use/settings/"
        case .glucoseDisplay:
            return "use/glucoseDisplay/"
        case .alertsAndNotifications:
            return "use/alertsAndNotifications/"
        case .dataManagement:
            return "use/dataManagement/"
        case .issueReporting:
            return "troubleshoot/reportingIssues/"
        case .activityLog:
            return "troubleshoot/activityLog/"
        case .nightscoutService:
            return "services/nightscout/"
        case .dexcomShareService:
            return "services/dexcomShare/"
        case .appleHealth:
            return "services/appleHealth/"
        case .calendarShare:
            return "services/calendarShare/"
        case .contactImage:
            return "display/contactImage/"
        case .osAidShare:
            return "services/osAidShare/"
        case .speakGlucose:
            return "display/speakGlucose/"
        case .snooze:
            return "use/snooze/"
        case .glucoseReadings:
            return "use/glucoseReadings/"
        case .sensorManagement, .calibration:
            return "use/sensor/"
        case .glucoseAdjustments:
            return "use/glucoseAdjustments/"
        case .quickShowHide:
            return "use/quickShowHide/"
        case .treatments:
            return "use/treatments/"
        case .statistics:
            return "use/statistics/"
        case .devices:
            return "use/devices/"
        case .addDirectCGM:
            return "connect/cgm/"
        case .dexcomG5G6One:
            return "connect/dexcomG5G6One/"
        case .dexcomG7OnePlusStelo:
            return "connect/dexcomG7OnePlusStelo/"
        case .libre2:
            return "connect/libre2/"
        case .libreTransmitters:
            return "connect/libreTransmitters/"
        case .medtrumNano:
            return "connect/medtrum/"
        case .followerHeartbeat:
            return "connect/followerHeartbeat/"
        case .m5Stack:
            return "connect/devices/"
        case .nightscoutFollower:
            return "connect/nightscoutFollower/"
        case .libreLinkUpFollower:
            return "connect/libreLinkUp/"
        case .dexcomShareFollower:
            return "connect/dexcomShareFollower/"
        case .sharedCalendarFollower:
            return "connect/sharedCalendar/"
        case .careLinkFollower:
            return "connect/careLink/"
        case .medtrumEasyViewFollower:
            return "connect/medtrumEasyView/"
        }
    }

    /// An optional heading identifier, without the leading `#`, for a topic within a shared page.
    ///
    /// Keep this value in sync with the heading ID generated by MkDocs. Most topics open at the
    /// top of their page and therefore return `nil`.
    var fragment: String? {
        switch self {
        case .calibration:
            return "when-calibration-is-available"
        default:
            return nil
        }
    }
}

// MARK: - URL construction and launching

/// Builds and launches direct or automatically translated online documentation links.
///
/// The documentation itself is English. If `translateOnlineHelp` is enabled and the app's chosen
/// language is not English, links are sent through Google Translate using that app language as
/// the target. Otherwise the canonical Read the Docs URL is used.
///
/// URL construction is kept separate from presentation so every screen gets identical behavior,
/// while tests can verify exact URLs without opening a browser. `URLComponents` is used rather
/// than string concatenation so query values and fragments are encoded safely.
enum OnlineHelp {
    private static let scheme = "https"
    private static let directHost = "xdrip4ios.readthedocs.io"
    private static let translatedHost = "xdrip4ios-readthedocs-io.translate.goog"
    private static let documentationBasePath = "/en/latest/"
    private static let documentationBaseLanguage = "en"

    /// Builds the production URL using the app language and the saved translation preference.
    ///
    /// This is the URL entry point app code should normally use. The overload accepting explicit
    /// values exists so URL behavior can be tested deterministically.
    static func url(for topic: OnlineHelpTopic) -> URL? {
        url(
            for: topic,
            languageIdentifier: Bundle.main.preferredLocalizations.first,
            translate: UserDefaults.standard.translateOnlineHelp
        )
    }

    /// Builds a help URL from explicit inputs.
    ///
    /// - Parameters:
    ///   - topic: The semantic documentation destination.
    ///   - languageIdentifier: The app localization identifier, such as `en`, `es`, or `pt-PT`.
    ///   - translate: Whether automatic translation is enabled in Settings.
    /// - Returns: A canonical or Google-translated URL, or `nil` if URL construction fails.
    static func url(
        for topic: OnlineHelpTopic,
        languageIdentifier: String?,
        translate: Bool
    ) -> URL? {
        let languageCode = normalizedLanguageCode(from: languageIdentifier)
        let shouldTranslate = translate
            && languageCode != nil
            && languageCode != documentationBaseLanguage

        var components = URLComponents()
        components.scheme = scheme
        components.host = shouldTranslate ? translatedHost : directHost
        components.path = documentationBasePath + topic.relativePath
        components.fragment = topic.fragment

        if shouldTranslate, let languageCode {
            components.queryItems = [
                URLQueryItem(name: "_x_tr_sl", value: "auto"),
                URLQueryItem(name: "_x_tr_tl", value: languageCode),
                URLQueryItem(name: "_x_tr_hl", value: languageCode),
                URLQueryItem(name: "_x_tr_pto", value: "nui")
            ]
        }

        return components.url
    }

    /// Opens a topic using the app language and saved translation preference.
    ///
    /// The caller supplies the opener so SwiftUI can use its `openURL` environment action. That
    /// opens the user's default browser and also keeps this service independent of a concrete UI.
    @MainActor
    static func open(_ topic: OnlineHelpTopic, using opener: (URL) -> Void) {
        guard let url = url(for: topic) else { return }
        opener(url)
    }

    /// Opens a topic using explicit URL inputs. This overload is intended for deterministic tests.
    @MainActor
    static func open(
        _ topic: OnlineHelpTopic,
        languageIdentifier: String?,
        translate: Bool,
        using opener: (URL) -> Void
    ) {
        guard let url = url(
            for: topic,
            languageIdentifier: languageIdentifier,
            translate: translate
        ) else { return }
        opener(url)
    }

    /// Reduces an Apple localization identifier to the language code Google Translate expects.
    ///
    /// For example, `pt-PT` becomes `pt` and `zh-Hans` becomes `zh`. A missing or empty app
    /// localization returns `nil`, which safely falls back to the canonical English page.
    static func normalizedLanguageCode(from identifier: String?) -> String? {
        guard let identifier, !identifier.isEmpty else { return nil }
        return Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
    }
}

// MARK: - Reusable SwiftUI controls

/// Standard question-mark control for online documentation toolbars and custom headers.
///
/// Prefer `View.onlineHelp(_:)` when a screen only needs a help toolbar item. Use this view
/// directly when adding help to an existing `ToolbarItemGroup`, to a `SettingsScreen` destination,
/// or to a custom header. The button owns all launching behavior, including the translation
/// preference, tint, symbol, and accessible label.
struct OnlineHelpButton: View {
    @Environment(\.openURL) private var openURL

    /// The documentation destination to open when the button is selected.
    let topic: OnlineHelpTopic

    var body: some View {
        Button {
            OnlineHelp.open(topic) { url in
                openURL(url)
            }
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .tint(ConstantsAppColors.toolbarAction)
        .accessibilityLabel(Texts_SettingsView.showOnlineHelp)
    }
}

private struct OnlineHelpToolbarModifier: ViewModifier {
    let topic: OnlineHelpTopic

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                OnlineHelpButton(topic: topic)
            }
        }
    }
}

extension View {
    /// Adds the standard online-help button to the trailing edge of a native navigation toolbar.
    ///
    /// Attach this to the screen that is inside the `NavigationStack`/`NavigationView`, rather than
    /// to an individual row. Native toolbar presentation also gives the control the system's
    /// current appearance, including Liquid Glass on supported iOS versions.
    func onlineHelp(_ topic: OnlineHelpTopic) -> some View {
        modifier(OnlineHelpToolbarModifier(topic: topic))
    }
}

// MARK: - Model-to-topic mappings

extension FollowerDataSourceType {
    /// The follower-specific setup guide used by the shared follower Settings screens.
    ///
    /// This switch is intentionally exhaustive so adding a follower source produces a compiler
    /// reminder to choose its help destination.
    var onlineHelpTopic: OnlineHelpTopic {
        switch self {
        case .nightscout:
            return .nightscoutFollower
        case .libreLinkUp, .libreLinkUpRussia:
            return .libreLinkUpFollower
        case .dexcomShare:
            return .dexcomShareFollower
        case .medtrumEasyView:
            return .medtrumEasyViewFollower
        case .calendar:
            return .sharedCalendarFollower
        case .careLink:
            return .careLinkFollower
        }
    }
}

extension BluetoothPeripheralType {
    /// The device guide that best matches this concrete Bluetooth peripheral type.
    ///
    /// Multiple hardware types can share one guide when their setup instructions are common.
    var onlineHelpTopic: OnlineHelpTopic {
        switch self {
        case .M5StackType, .M5StickCType:
            return .m5Stack
        case .Libre2Type:
            return .libre2
        case .MiaoMiaoType, .BubbleType:
            return .libreTransmitters
        case .DexcomType:
            return .dexcomG5G6One
        case .DexcomG7Type:
            return .dexcomG7OnePlusStelo
        case .Libre3HeartBeatType, .DexcomG7HeartBeatType, .OmniPodHeartBeatType:
            return .followerHeartbeat
        case .MedtrumTouchCareNanoType:
            return .medtrumNano
        }
    }
}

extension BluetoothPeripheralCategory {
    /// The overview guide shown while the user is choosing a device within this category.
    var onlineHelpTopic: OnlineHelpTopic {
        switch self {
        case .CGM:
            return .addDirectCGM
        case .M5Stack:
            return .m5Stack
        case .HeartBeat:
            return .followerHeartbeat
        }
    }
}
