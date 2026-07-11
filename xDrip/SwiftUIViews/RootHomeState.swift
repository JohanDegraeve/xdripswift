//
//  RootHomeState.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// Published display state for the SwiftUI home screen.
///
/// This is deliberately a presentation model, not a new owner of app services. During the first
/// RootViewController migration slice, the existing controller still owns Core Data, Bluetooth,
/// Nightscout, alerts, notifications and app lifecycle callbacks. It mirrors the values that used
/// to be written directly into UIKit labels into this state so SwiftUI can render the home screen
/// without reaching into every manager.
struct RootHomeState {

    var glucose = RootHomeGlucoseState()
    var pump = RootHomePumpState()
    var loop = RootHomeLoopState()
    var statistics = RootHomeStatisticsState()
    var sensor = RootHomeSensorState()
    var dataSource = RootHomeDataSourceState()
    var visibility = RootHomeVisibilityState()
    var controls = RootHomeControlsState()
    var isScreenLocked = false

}

struct RootHomeGlucoseState {
    var valueText = "---"
    var valueColor = ConstantsAppColors.disabledText
    var valueHasStrikethrough = false
    var minutesText = ""
    var minutesAgoText = ""
    var minutesColor = ConstantsAppColors.primaryText
    var deltaText = ""
    var deltaUnitText = ""
    var deltaColor = ConstantsAppColors.primaryText
}

struct RootHomePumpState {
    var basal = RootHomeMetricState(title: "Basal", value: "-")
    var reservoir = RootHomeMetricState(title: "Reservoir", value: "-")
    var battery = RootHomeMetricState(title: "Battery", value: "-")
    var cage = RootHomeMetricState(title: "CAGE", value: "-")
}

struct RootHomeLoopState {
    var iob = RootHomeMetricState(title: "IOB", value: "-")
    var cob = RootHomeMetricState(title: "COB", value: "-")
    var statusTitle = "-"
    var statusSystemImage: String?
    var statusColor = ConstantsAppColors.secondaryText
    var statusTimeAgo = ""
    var showsStatusTimeAgo = false
    var showsActivityIndicator = false
    var showsUploaderBattery = false
}

struct RootHomeStatisticsState {
    var low = RootHomeMetricState(title: Texts_Common.lowStatistics, value: "-")
    var inRange = RootHomeMetricState(title: UserDefaults.standard.timeInRangeType.title, value: "-")
    var high = RootHomeMetricState(title: Texts_Common.highStatistics, value: "-")
    var average = RootHomeMetricState(title: Texts_Common.averageStatistics, value: "-")
    var a1c = RootHomeMetricState(title: Texts_Common.a1cStatistics, value: "-")
    var cv = RootHomeMetricState(title: Texts_Common.cvStatistics, value: "-")
    var lowLimitText = ""
    var highLimitText = ""
    var timePeriodText = "- - -"
    var showsActivityIndicator = false
}

struct RootHomeSensorState {
    var title = ""
    var currentAge = ""
    var maxAge = ""
    var currentAgeColor = ConstantsAppColors.primaryText
    var progressColor = ConstantsAppColors.disabledText
    var progress: Double = 0
}

struct RootHomeDataSourceState {
    var title = ""
    var detail = ""
    var detailColor = ConstantsAppColors.secondaryText
    var showsConnectionIcon = false
    var connectionSystemImage = "network.slash"
    var connectionColor = ConstantsAppColors.urgent
    var showsKeepAliveIcon = false
    var keepAliveSystemImage = "antenna.radiowaves.left.and.right"
    var keepAliveColor = ConstantsAppColors.secondaryText
}

struct RootHomeVisibilityState {
    var showsPump = false
    var showsLoop = false
    var showsMiniChart = false
    var showsStatistics = false
    var showsSensor = false
    var showsDataSource = false
    var showsControls = true
    var showsClock = false
}

struct RootHomeControlsState {
    var chartHours = UserDefaults.standard.chartWidthInHours
    var statisticsDays = UserDefaults.standard.daysToUseStatistics
    var clockText = ""
    var sensorButtonEnabled = UserDefaults.standard.isMaster
    var postProcessingSystemImage = "dial.medium"
    var postProcessingEnabled = false
    var snoozeSystemImage = "speaker.wave.2"
}

struct RootHomeMetricState: Identifiable {
    var title: String
    var value: String
    var valueColor = ConstantsAppColors.primaryText

    var id: String {
        title
    }
}

/// Observable container used by `RootViewController` to publish home screen display changes.
///
/// Keeping this as a tiny holder avoids making the SwiftUI view depend on the controller directly.
/// It also gives us a clean place to move state calculation later when RootViewController is thinned
/// into a coordinator.
final class RootHomeDisplayManager: ObservableObject {

    @Published private(set) var state = RootHomeState()

    func update(_ state: RootHomeState) {
        // RootViewController can receive follower, statistics and Core Data callbacks away from
        // the main queue. UIKit outlet reads should eventually be moved out of those callbacks, but
        // during this bridge phase the important rule is that SwiftUI is only published on main.
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    self.state = state
                }
            }
            
            return
        }
        
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            self.state = state
        }
    }

}

/// Actions that the SwiftUI home screen can ask the existing RootViewController coordinator to run.
///
/// These closures keep view code declarative while preserving the current UIKit presentation,
/// calibration, sensor management, screen lock and alert flows during the migration.
struct RootHomeActions {
    var showSnooze: () -> Void = {}
    var showBgReadings: () -> Void = {}
    var showSensorManagement: () -> Void = {}
    var showBgAdjustments: () -> Void = {}
    var showHideItems: () -> Void = {}
    var toggleScreenLock: () -> Void = {}
    var keepScreenAwake: () -> Void = {}
    var toggleExpandedAIDInfo: () -> Void = {}
    var refreshPumpAndLoopStatus: () -> Void = {}
    var chartHoursChanged: (Double) -> Void = { _ in }
    var statisticsDaysChanged: (Int) -> Void = { _ in }
    var miniChartHoursChanged: (Double) -> Void = { _ in }
    var cycleStatisticsType: () -> Void = {}
    var hideFollowerUrl: () -> Void = {}
    var showAIDStatus: () -> Void = {}
}
