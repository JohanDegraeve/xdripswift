/// constants for home view, ie first view

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
struct StatusSymbolPresentation: Equatable {
    let systemImage: String
    let color: Color
}
#endif

/// Dexcom's role in the transmitter connection. The symbol is shared so every surface uses the
/// same visual language, while each view remains responsible for deciding whether to show it.
enum DexcomConnectionMode: String, Codable, Hashable {
    case primary
    case coexistence

    init(useOtherApp: Bool) {
        self = useOtherApp ? .coexistence : .primary
    }

    var systemImage: String {
        switch self {
        case .primary: return "p.square.fill"
        case .coexistence: return "c.square.fill"
        }
    }
}

/// Common AID status symbols for Home, AID details, Watch, widgets and Live Activities.
/// Keep the symbol names and weight choices here so a change reaches every AID status view.
/// Each view still chooses its own size and color to suit the space available.
/// This enum is used for presentation only. The shared AIDStatus payload stays unchanged.
enum AIDStatusSymbol: String, CaseIterable {
    /// An active Loop status. Recent and aging loops use the same circle with different colors.
    case loop = "circle"
    /// A loop that has not run recently, or whose device status is no longer current.
    case loopUnavailable = "circle.slash"
    /// CareLink pump delivery without SmartGuard. Also used for accounts reporting IOB without a pump.
    case pump = "checkmark.circle.fill"
    /// CareLink SmartGuard status, including its initial checking state.
    case smartGuard = "shield.lefthalf.filled"
    /// CareLink has reported that insulin delivery is suspended.
    case suspended = "pause.circle.fill"
    /// CareLink has reported that the pump is disconnected or out of range.
    case disconnected = "exclamationmark.triangle.fill"
    /// CareLink pump data is no longer current.
    case stale = "clock.badge.exclamationmark"

    /// Circle-based symbols use the strongest weight so their outlines remain clear at small sizes.
    /// Return nil for the other symbols to preserve the weight chosen by their containing view.
    /// Black is the SF Symbol font weight here, not the symbol color.
    var weight: Font.Weight? {
        switch self {
        case .loop, .loopUnavailable, .pump, .suspended: return .black
        case .smartGuard, .disconnected, .stale: return nil
        }
    }

}

/// Draw an AID symbol using the common weight while inheriting the containing view's font size.
/// Accept the enum directly so views cannot accidentally supply an unrelated SF Symbol name.
/// Keep the weight modifier on the image itself so an outer bold modifier cannot replace it.
struct AIDStatusSymbolImage: View {
    let symbol: AIDStatusSymbol

    var body: some View {
        if let weight = symbol.weight {
            Image(systemName: symbol.rawValue).fontWeight(weight)
        } else {
            // Do not apply fontWeight(nil) here. That would clear an inherited weight instead of keeping it.
            Image(systemName: symbol.rawValue)
        }
    }
}

enum AIDStatusCondition: String, Codable, Hashable {
    case active
    case checking
    case suspended
    case disconnected
}

enum AIDStatusStyle: String, Codable, Hashable {
    case loop
    case careLinkPump
    case careLinkSmartGuard
    /// CareLink has reported active insulin without reporting a pump.
    /// This reuses the shared therapy-status transport without presenting the source as an AID.
    case careLinkIOB
}

/// Common AID state prevents Home, widgets and the Watch from interpreting the same source
/// differently. It contains only semantic values and can therefore cross process boundaries.
struct AIDStatus: Codable, Hashable {
    let condition: AIDStatusCondition
    let style: AIDStatusStyle
    let statusUpdatedAt: Date?
    let lastActivityAt: Date?
    let iob: Double?
    let cob: Double?
    let statusTitle: String
    let staleStatusTitle: String

    /// Whether this provider can publish a time-varying carbs-on-board value.
    ///
    /// CareLink supplies discrete meal entries but no active-carbohydrate amount or decay model.
    /// Treating an entered meal as COB would leave the full grams visible indefinitely and would
    /// therefore be clinically misleading. Nightscout AID status carries the COB calculated by
    /// the configured loop algorithm and remains eligible for the compact Home and Watch metric.
    var supportsCOB: Bool {
        style == .loop
    }

    func presentation(referenceDate: Date = .now) -> AIDStatusPresentation {
        // A non-pump CareLink account has no delivery state to interpret. Only the age of its IOB
        // report is meaningful, so keep that presentation separate from the AID condition switch.
        if style == .careLinkIOB {
            return careLinkIOBPresentation(referenceDate: referenceDate)
        }

        let hasFreshData = statusUpdatedAt.map {
            $0 <= referenceDate.addingTimeInterval(ConstantsHomeView.aidStatusFutureTolerance)
                && $0 > referenceDate.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes)
        } ?? false

        switch condition {
        case .checking:
            return AIDStatusPresentation(
                title: statusTitle,
                symbol: style == .loop ? nil : .smartGuard,
                color: Color("colorSecondary"),
                hasFreshData: false,
                showsActivityAge: false,
                showsActivityIndicator: true
            )
        case .suspended:
            return AIDStatusPresentation(
                title: statusTitle,
                symbol: .suspended,
                color: .yellow,
                hasFreshData: hasFreshData,
                showsActivityAge: lastActivityAt != nil,
                showsActivityIndicator: false
            )
        case .disconnected:
            return AIDStatusPresentation(
                title: statusTitle,
                symbol: .disconnected,
                color: .red,
                hasFreshData: hasFreshData,
                showsActivityAge: lastActivityAt != nil,
                showsActivityIndicator: false
            )
        case .active:
            if style == .loop {
                let loopState = LoopStatusState(
                    deviceStatusCreatedAt: statusUpdatedAt,
                    lastLoopDate: lastActivityAt,
                    referenceDate: referenceDate
                )
                return AIDStatusPresentation(
                    title: loopState.title,
                    symbol: loopState.symbol,
                    color: loopState.color,
                    hasFreshData: hasFreshData,
                    showsActivityAge: loopState.showsLoopAge,
                    showsActivityIndicator: false
                )
            }

            return AIDStatusPresentation(
                title: hasFreshData ? statusTitle : staleStatusTitle,
                symbol: hasFreshData ? activeSymbol : .stale,
                color: hasFreshData ? .green : .yellow,
                hasFreshData: hasFreshData,
                showsActivityAge: lastActivityAt != nil,
                showsActivityIndicator: false
            )
        }
    }

    private var activeSymbol: AIDStatusSymbol {
        style == .careLinkSmartGuard
            ? .smartGuard
            : .pump
    }

    /// Active insulin from a non-pump CareLink response is data, not an AID state. Its single
    /// checkmark changes color with age so every consumer presents the same freshness signal.
    private func careLinkIOBPresentation(referenceDate: Date) -> AIDStatusPresentation {
        let latestAllowedDate = referenceDate.addingTimeInterval(ConstantsHomeView.aidStatusFutureTolerance)
        let warningDate = referenceDate.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes)
        let noDataDate = referenceDate.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes)
        let color: Color
        let hasFreshData: Bool

        // Match the existing AID age thresholds while retaining one checkmark shape. A changing
        // pump/AID symbol would imply delivery modes that this account does not report.
        if let statusUpdatedAt, statusUpdatedAt <= latestAllowedDate, statusUpdatedAt > warningDate {
            color = .green
            hasFreshData = true
        } else if let statusUpdatedAt, statusUpdatedAt <= latestAllowedDate, statusUpdatedAt > noDataDate {
            color = .yellow
            hasFreshData = true
        } else {
            color = .red
            hasFreshData = false
        }

        return AIDStatusPresentation(
            title: hasFreshData ? statusTitle : staleStatusTitle,
            symbol: .pump,
            color: color,
            hasFreshData: hasFreshData,
            showsActivityAge: lastActivityAt != nil,
            showsActivityIndicator: false
        )
    }
}

/// Resolved display state for the current AID reading, shared by all presentation surfaces.
/// Carry the typed symbol through to the renderer instead of converting it to a string and back.
struct AIDStatusPresentation {
    let title: String
    /// A checking Loop has no symbol and uses the activity indicator instead.
    let symbol: AIDStatusSymbol?
    let color: Color
    let hasFreshData: Bool
    let showsActivityAge: Bool
    let showsActivityIndicator: Bool
}

enum LoopStatusState {
    case recent
    case aging
    case notLooping
    case noData

    init(deviceStatusCreatedAt: Date?, lastLoopDate: Date?, referenceDate: Date = .now) {
        let latestAllowedDate = referenceDate.addingTimeInterval(60)
        let warningDate = referenceDate.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes)
        let noDataDate = referenceDate.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes)

        guard let deviceStatusCreatedAt, deviceStatusCreatedAt != .distantPast, deviceStatusCreatedAt <= latestAllowedDate, deviceStatusCreatedAt > noDataDate else {
            self = .noData
            return
        }

        if let lastLoopDate, lastLoopDate != .distantPast, lastLoopDate <= latestAllowedDate {
            if lastLoopDate > warningDate {
                self = .recent
                return
            } else if lastLoopDate > noDataDate {
                self = .aging
                return
            }
        }

        self = .notLooping
    }

    var color: Color {
        switch self {
        case .recent:
            return .green
        case .aging:
            return .yellow
        case .notLooping:
            return .red
        case .noData:
            return .gray
        }
    }

    #if os(iOS)
    var uiColor: UIColor {
        switch self {
        case .recent:
            return .systemGreen
        case .aging:
            return .systemYellow
        case .notLooping:
            return .systemRed
        case .noData:
            return .systemGray
        }
    }
    #endif

    var title: String {
        switch self {
        case .recent, .aging:
            return "Looping"
        case .notLooping:
            return "Not looping"
        case .noData:
            return "No data"
        }
    }

    /// Freshness changes the color, while missing or inactive loops use the slashed circle.
    /// Weight comes from the shared symbol so these states look consistent in every view.
    var symbol: AIDStatusSymbol {
        switch self {
        case .recent:
            return .loop
        case .aging:
            return .loop
        case .notLooping:
            return .loopUnavailable
        case .noData:
            return .loopUnavailable
        }
    }

    var showsLoopAge: Bool {
        self != .noData
    }
}

enum ConstantsHomeView {

    /// Standard corner radius for Home panels and compact status views.
    static let standardCornerRadius: CGFloat = 10

    /// Magnification change required before a main-chart pinch changes the visible range.
    static let mainChartZoomMagnificationThreshold = 0.15

    /// How long the selected main-chart range remains fully visible after a pinch.
    static let mainChartZoomOverlayVisibleDuration = 1.5

    /// Duration of the main-chart range overlay fade-out animation.
    static let mainChartZoomOverlayFadeDuration = 1.0

    /// How long the main chart retains an expanded upper y-axis after scrolling stops.
    static let mainChartYAxisAutoResetDelay = 10.0
    
    /// how often to update the labels in the homeview (ie label with latest reading, minutes ago, etc..)
    static let updateHomeViewIntervalInSeconds = 15.0
    
    /// info email adres, appears in licenseInfo
    static let infoEmailAddress = "xdrip@proximus.be"
    
    /// application name, appears in licenseInfo as title
    static let applicationName: String = {

        guard let dictionary = Bundle.main.infoDictionary else {return "unknown"}
        
        guard let version = dictionary["CFBundleDisplayName"] as? String else {return "unknown"}
        
        return version
        
    }()
  
    /// github.com repository URL for the project
    static let gitHubURL = "https://github.com/JohanDegraeve/xdripswift"

    /// github.com repository name for the project
    static let gitHubRepositoryName = "xdripswift"

    /// license type for the project
    static let licenseType = "GNU GPL v3"
    
    // MARK: - Sensor Info View
    
    /// how many seconds the Nightscout URL (if displayed in the data source info view) should be hidden when double tapped
    static let hideUrlDuringTimeInSeconds: Int = 10
    
    /// warning time left / colour
    static let sensorProgressViewWarningInMinutes: Double = 60 * 24.0 // 24 hours before the sensor reaches max age
    static let sensorProgressViewProgressColorWarningSwiftUI: Color = .yellow
    
    /// urgent time left / colour
    static let sensorProgressViewUrgentInMinutes: Double = 60 * 12.0 // 12 hours before the sensor reaches max age
    static let sensorProgressViewProgressColorUrgentSwiftUI: Color = .orange
    
    /// colour for an expired sensor
    static let sensorProgressExpiredSwiftUI: Color = .red
    
    /// colour for an normal text
    static let sensorProgressNormalTextColorSwiftUI: Color = .white
    static let sensorProgressViewNormalColorSwiftUI: Color = .gray

    /// duration of the sensor progress entrance animation
    static let sensorProgressEntranceAnimationDuration: TimeInterval = 0.4
    
    // MARK: - Screen lock
    
    /// colour for the dimmed screen lock overlay view
    static let screenLockDimmingOptionsDimmed = Color.black.opacity(0.3)
    
    /// colour for the dark screen lock overlay view
    static let screenLockDimmingOptionsDark = Color.black.opacity(0.5)
    
    /// colour for the very dark screen lock overlay view
    static let screenLockDimmingOptionsVeryDark = Color.black.opacity(0.7)
    
    // MARK: - For loop/AID status
    
    /// after how many seconds should the loop status be shown as a warning
    static let loopShowWarningAfterMinutes: TimeInterval = 60 * 12
    
    /// after how many seconds should the loop status be shown as having no current data to show
    static let loopShowNoDataAfterMinutes: TimeInterval = 60 * 17

    /// Allows a small amount of clock skew in status timestamps supplied by remote systems.
    static let aidStatusFutureTolerance: TimeInterval = 60

    /// opacity level for the background of the AID status banner
    static let AIDStatusBannerBackgroundOpacity = 0.1
    
    /// number of hours for the default canula max age (usually 3 days = 72 hours)
    static let CAGEDefaultMaxHours: Int = 72
    
    /// after much time *before max hours* should we show the CAGE as a warning condition (yellow)?
    static let CAGEWarningTimeIntervalBeforeMaxHours: TimeInterval = 60 * 60 * 12
    
    /// after much time *before max hours* should we show the CAGE as an urgent condition (red)?
    static let CAGEUrgentTimeIntervalBeforeMaxHours: TimeInterval = 60 * 60 * 6
    
    /// below how many units should we show the pump reservoir  as a warning condition (yellow)?
    static let pumpReservoirWarning: Double = 30
    
    /// below how many units should we show the pump reservoir as an urgent condition (red)?
    static let pumpReservoirUrgent: Double = 10
    
    /// below what percentage should we show the pump battery as a warning condition (yellow)?
    static let pumpBatteryPercentWarning: Int = 20
    
    /// below what percentage should we show the pump battery as an urgent condition (red)?
    static let pumpBatteryPercentUrgent: Int = 10

    #if os(iOS)
    /// Uses the same sensor lifetime thresholds in Home and the CareLink status screen.
    static func careLinkSensorIndicator(remainingMinutes: Int) -> StatusSymbolPresentation {
        let color: Color
        if remainingMinutes <= 0 {
            color = .red
        } else if remainingMinutes <= Int(sensorProgressViewUrgentInMinutes) {
            color = .orange
        } else if remainingMinutes <= Int(sensorProgressViewWarningInMinutes) {
            color = .yellow
        } else {
            color = .green
        }
        return StatusSymbolPresentation(systemImage: "sensor.tag.radiowaves.forward.fill", color: color)
    }

    /// Provides the battery symbol buckets and colors shared by Loop and CareLink status rows.
    static func batteryIndicator(percent: Int?) -> StatusSymbolPresentation? {
        guard let percent else { return nil }

        switch percent {
        case 0...10:
            if #available(iOS 17.0, *) {
                return StatusSymbolPresentation(systemImage: "battery.0percent", color: .red)
            } else {
                return StatusSymbolPresentation(systemImage: "minus.plus.batteryblock.slash", color: .red)
            }
        case 11...25:
            if #available(iOS 17.0, *) {
                return StatusSymbolPresentation(systemImage: "battery.25percent", color: .yellow)
            } else {
                return StatusSymbolPresentation(systemImage: "minus.plus.batteryblock", color: .yellow)
            }
        case 26...65:
            if #available(iOS 17.0, *) {
                return StatusSymbolPresentation(systemImage: "battery.50percent", color: Color("colorSecondary"))
            } else {
                return StatusSymbolPresentation(systemImage: "minus.plus.batteryblock", color: Color("colorSecondary"))
            }
        case 66...90:
            if #available(iOS 17.0, *) {
                return StatusSymbolPresentation(systemImage: "battery.75percent", color: Color("colorSecondary"))
            } else {
                return StatusSymbolPresentation(systemImage: "minus.plus.batteryblock.fill", color: Color("colorSecondary"))
            }
        default:
            if #available(iOS 17.0, *) {
                return StatusSymbolPresentation(systemImage: "battery.100percent", color: Color("colorSecondary"))
            } else {
                return StatusSymbolPresentation(systemImage: "minus.plus.batteryblock.fill", color: Color("colorSecondary"))
            }
        }
    }
    #endif
    
}
