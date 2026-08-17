//
//  RootHomeState.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Presentation State

/// Complete presentation state for the SwiftUI home screen.
///
/// The values are independent of any individual view and can be shared by portrait and landscape.
struct RootHomeState {

    var glucose = RootHomeGlucoseState()
    var pump = RootHomePumpState()
    var loop = RootHomeLoopState()
    var statistics = RootHomeStatisticsState()
    var sensor = RootHomeSensorState()
    var sensorNoise = RootHomeSensorNoiseState()
    var dataSource = RootHomeDataSourceState()
    var visibility = RootHomeVisibilityState()
    var controls = RootHomeControlsState()
    var isScreenLocked = false
    var usesScreenLockNightLayout = false
    var chartRevision = 0
    var chartResetToNowRevision = 0

}

/// Formatted glucose value, age and delta shown by portrait and landscape Home views.
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

/// Pump metrics displayed beside the current glucose reading.
struct RootHomePumpState {
    var basal = RootHomeMetricState(title: "Basal", value: "-")
    var reservoir = RootHomeMetricState(title: Texts_HomeView.pumpReservoir, value: "-")
    var battery = RootHomeMetricState(title: Texts_HomeView.pumpBattery, value: "-")
    var cage = RootHomeMetricState(title: "CAGE", value: "-")
    var isHistorical = false
}

/// Loop status and optional uploader-battery presentation.
struct RootHomeLoopState {
    var iob = RootHomeMetricState(title: "IOB", value: "- U")
    var cob = RootHomeMetricState(title: "COB", value: "- g")
    var showsCOB = true
    var statusTitle = "-"
    var statusSystemImage: String?
    var statusColor = ConstantsAppColors.secondaryText
    var statusTimeAgo = ""
    var showsStatusTimeAgo = false
    var showsActivityIndicator = false
    var showsUploaderBattery = false
    var uploaderBatterySystemImage = "battery.75"
    var uploaderBatteryColor = ConstantsAppColors.primaryText
    var isHistorical = false
}

/// Calculated statistics and their loading state for the selected period.
struct RootHomeStatisticsState {
    var low = RootHomeMetricState(title: Texts_Common.lowStatistics, value: "-")
    var inRange = RootHomeMetricState(title: UserDefaults.standard.timeInRangeType.title, value: "-")
    var high = RootHomeMetricState(title: Texts_Common.highStatistics, value: "-")
    var average = RootHomeMetricState(title: Texts_Common.averageStatistics, value: "-")
    var a1c = RootHomeMetricState(title: Texts_Common.a1cStatistics, value: "-")
    var cv = RootHomeMetricState(title: Texts_Common.cvStatistics, value: "-")
    var lowLimitText = ""
    var highLimitText = ""
    var showsActivityIndicator = false
}

/// Picker values and labels for the selected statistics calculation period.
enum RootHomeStatisticsPeriod {
    static let options = [0, 1, 7, 30, 90]

    static func title(for days: Int) -> String {
        switch days {
        case 0:
            return Texts_Common.today
        case 1:
            return "1 \(Texts_Common.day)"
        default:
            return "\(days) \(Texts_Common.days)"
        }
    }
}

/// Active sensor lifetime presentation.
struct RootHomeSensorState {
    var title = ""
    var currentAge = ""
    var maxAge = ""
    var currentAgeColor = ConstantsAppColors.primaryText
    var progressColor = ConstantsAppColors.disabledText
    var progress: Double = 0
    var countsDown = false
}

/// Current sensor-noise indicator for fresh master-mode readings.
struct RootHomeSensorNoiseState {
    var showsIndicator = false
    var indicatorColor = ConstantsAppColors.secondaryText
    var indicatorAccessibilityLabel = ""
}

/// Current data-source description and connection indicators.
struct RootHomeDataSourceState {
    var title = ""
    var detail = ""
    var detailColor = ConstantsAppColors.secondaryText
    var detailSystemImage: String?
    var detailSystemImageColor = ConstantsAppColors.secondaryText
    var detailSystemImageAccessibilityLabel = ""
    var showsConnectionIcon = false
    var connectionColor = ConstantsAppColors.urgent
    var showsKeepAliveIcon = false
    var keepAliveSystemImage = "antenna.radiowaves.left.and.right"
    var keepAliveColor = ConstantsAppColors.secondaryText
}

/// Controls which optional Home sections are included in the current layout.
struct RootHomeVisibilityState {
    var showsPump = false
    var showsLoop = false
    var showsMiniChart = false
    var showsStatistics = false
    var showsSensor = false
    var showsDataSource = false
    var showsClock = false
}

/// Values used by Home controls which are not part of the clinical status sections.
struct RootHomeControlsState {
    var statisticsDays = UserDefaults.standard.daysToUseStatistics
    var clockText = ""
    var sensorButtonEnabled = UserDefaults.standard.isMaster
    var postProcessingSystemImage = "dial.medium"
    var postProcessingEnabled = false
    var snoozeSystemImage = "speaker.wave.2"
}

/// One title, value and color used by the compact Home metric views.
struct RootHomeMetricState: Identifiable {
    var title: String
    var value: String
    var valueColor = ConstantsAppColors.primaryText

    var id: String {
        title
    }
}

// MARK: - State Model

/// Main state model for the SwiftUI home screen.
///
/// `RootApplicationCoordinator` owns long-lived services and calls `refresh` from application,
/// glucose and follower callbacks. This model calculates presentation values directly from those
/// services and publishes one consistent Home state.
final class RootHomeStateModel: ObservableObject {

    @Published private(set) var state = RootHomeState()

    private var followerURLHiddenUntil: Date?
    private var showsFollowerURLHidingMessage = false
    private var bgReadingsAccessor: BgReadingsAccessor?
    private var treatmentEntryAccessor: TreatmentEntryAccessor?
    private var nightscoutSyncManager: NightscoutSyncManager?
    private var bluetoothPeripheralManager: BluetoothPeripheralManager?
    private var alertManager: AlertManager?
    private var bgPostProcessingManager: BgPostProcessingManager?

    // MARK: - Configuration and Refresh

    /// Attaches the existing application services without taking ownership of them.
    func configure(
        bgReadingsAccessor: BgReadingsAccessor,
        treatmentEntryAccessor: TreatmentEntryAccessor,
        nightscoutSyncManager: NightscoutSyncManager,
        bluetoothPeripheralManager: BluetoothPeripheralManager,
        alertManager: AlertManager,
        bgPostProcessingManager: BgPostProcessingManager
    ) {
        self.bgReadingsAccessor = bgReadingsAccessor
        self.treatmentEntryAccessor = treatmentEntryAccessor
        self.nightscoutSyncManager = nightscoutSyncManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.alertManager = alertManager
        self.bgPostProcessingManager = bgPostProcessingManager
    }

    /// Rebuilds the complete lightweight presentation state from the latest manager values.
    func refresh(activeSensor: Sensor?, isScreenLocked: Bool, usesScreenLockNightLayout: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.refresh(
                    activeSensor: activeSensor,
                    isScreenLocked: isScreenLocked,
                    usesScreenLockNightLayout: usesScreenLockNightLayout
                )
            }

            return
        }

        let latestReadings = bgReadingsAccessor?.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4) ?? []
        let latestSiteChangeDate = treatmentEntryAccessor?.latestSiteChangeDate()
        let dataFlowPolicy = UserDefaults.standard.dataFlowPolicy
        let careLinkSnapshot = CareLinkAccountState.shared.snapshot
        let deviceStatus = dataFlowPolicy.importsTherapyFromCareLink
            ? careLinkSnapshot.pump.homeDeviceStatus(metadata: careLinkSnapshot.metadata, checkedAt: careLinkSnapshot.lastCheckAt)
            : nightscoutSyncManager?.deviceStatus as? NightscoutDeviceStatus
        let cgmTransmitter = bluetoothPeripheralManager?.getCGMTransmitter()
        let cgmConnectionStatus: BluetoothPeripheralDisplayStatus?
        if let cgmTransmitter = cgmTransmitter as? BluetoothTransmitter,
           let cgmPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: cgmTransmitter) {
            cgmConnectionStatus = BluetoothPeripheralDisplayStatus(
                bluetoothTransmitter: cgmTransmitter,
                bluetoothPeripheral: cgmPeripheral
            )
        } else {
            cgmConnectionStatus = nil
        }

        var newState = state
        newState.glucose = glucoseState(from: latestReadings)
        newState.pump = pumpState(deviceStatus: deviceStatus, latestSiteChangeDate: latestSiteChangeDate)
        newState.loop = dataFlowPolicy.importsTherapyFromCareLink
            ? careLinkLoopState(snapshot: careLinkSnapshot)
            : loopState(deviceStatus: deviceStatus)
        newState.sensor = sensorState(activeSensor: activeSensor, cgmTransmitter: cgmTransmitter)
        newState.sensorNoise = sensorNoiseState(activeSensor: activeSensor)
        newState.dataSource = dataSourceState(
            sensorState: newState.sensor,
            activeSensor: activeSensor,
            cgmTransmitter: cgmTransmitter,
            connectionStatus: cgmConnectionStatus
        )
        newState.visibility = visibilityState(sensorState: newState.sensor, usesScreenLockNightLayout: usesScreenLockNightLayout)
        newState.controls = controlsState(alertManager: alertManager, bgPostProcessingManager: bgPostProcessingManager)
        newState.isScreenLocked = isScreenLocked
        newState.usesScreenLockNightLayout = usesScreenLockNightLayout

        publish(newState)
    }

    /// Refreshes cloud pump presentation without recalculating unrelated Home controls.
    ///
    /// Pump followers can publish several state changes during one request. Keeping this update
    /// focused avoids repeatedly evaluating alert snooze state for pump-only changes.
    func refreshPumpAndLoopStatus() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.refreshPumpAndLoopStatus()
            }

            return
        }

        let dataFlowPolicy = UserDefaults.standard.dataFlowPolicy
        let careLinkSnapshot = CareLinkAccountState.shared.snapshot
        let deviceStatus = dataFlowPolicy.importsTherapyFromCareLink
            ? careLinkSnapshot.pump.homeDeviceStatus(metadata: careLinkSnapshot.metadata, checkedAt: careLinkSnapshot.lastCheckAt)
            : nightscoutSyncManager?.deviceStatus as? NightscoutDeviceStatus
        let latestSiteChangeDate = treatmentEntryAccessor?.latestSiteChangeDate()

        updateState { state in
            state.pump = self.pumpState(
                deviceStatus: deviceStatus,
                latestSiteChangeDate: latestSiteChangeDate
            )
            state.loop = dataFlowPolicy.importsTherapyFromCareLink
                ? self.careLinkLoopState(snapshot: careLinkSnapshot)
                : self.loopState(deviceStatus: deviceStatus)
        }
    }

    func setStatisticsLoading() {
        updateState { state in
            state.statistics.showsActivityIndicator = state.statistics.average.value != "-"
            state.statistics.low.value = "-"
            state.statistics.inRange.value = "-"
            state.statistics.high.value = "-"
            state.statistics.average.value = "-"
            state.statistics.a1c.value = "-"
            state.statistics.cv.value = "-"
        }
    }

    func updateStatistics(_ statistics: StatisticsManager.Statistics) {
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let hasData = statistics.averageStatisticValue.value > 0
        let glucoseUnit = isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        let averageValue = hasData
            ? statistics.averageStatisticValue.bgValueToString(mgDl: isMgDl) + " " + glucoseUnit
            : "-"
        let a1cValue: String

        if statistics.a1CStatisticValue.value <= 0 {
            a1cValue = "-"
        } else if UserDefaults.standard.useIFCCA1C {
            a1cValue = "\(Int(statistics.a1CStatisticValue.round(toDecimalPlaces: 0))) mmol"
        } else {
            a1cValue = "\(statistics.a1CStatisticValue.round(toDecimalPlaces: 1))%"
        }

        updateState { state in
            state.statistics = RootHomeStatisticsState(
                low: RootHomeMetricState(title: Texts_Common.lowStatistics, value: "\(Int(statistics.lowStatisticValue.round(toDecimalPlaces: 0)))%", valueColor: ConstantsAppColors.statisticsLow),
                inRange: RootHomeMetricState(title: UserDefaults.standard.timeInRangeType.title, value: "\(Int(statistics.inRangeStatisticValue.round(toDecimalPlaces: 0)))%", valueColor: ConstantsAppColors.statisticsInRange),
                high: RootHomeMetricState(title: Texts_Common.highStatistics, value: "\(Int(statistics.highStatisticValue.round(toDecimalPlaces: 0)))%", valueColor: ConstantsAppColors.statisticsHigh),
                average: RootHomeMetricState(title: Texts_Common.averageStatistics, value: averageValue),
                a1c: RootHomeMetricState(title: Texts_Common.a1cStatistics, value: a1cValue),
                cv: RootHomeMetricState(title: Texts_Common.cvStatistics, value: statistics.cVStatisticValue.value > 0 ? "\(Int(statistics.cVStatisticValue.round(toDecimalPlaces: 0)))%" : "-"),
                lowLimitText: "(<\(self.formattedLimit(statistics.lowLimitForTIR, isMgDl: isMgDl)))",
                highLimitText: "(>\(self.formattedLimit(statistics.highLimitForTIR, isMgDl: isMgDl)))",
                showsActivityIndicator: false
            )
        }
    }

    func updateClock() {
        updateState { state in
            state.controls.clockText = Date.now.formatted(date: .omitted, time: .shortened)
        }
    }

    func invalidateCharts() {
        updateState { state in
            state.chartRevision &+= 1
        }
    }

    func resetChartsToNow() {
        updateState { state in
            state.chartResetToNowRevision &+= 1
        }
    }

    func hideFollowerURL() {
        guard !UserDefaults.standard.isMaster,
              UserDefaults.standard.nightscoutEnabled,
              UserDefaults.standard.followerDataSourceType == .nightscout,
              UserDefaults.standard.nightscoutUrl != nil,
              UserDefaults.standard.followerPatientName == nil
        else {
            return
        }

        updateState { state in
            state.dataSource.detail = Texts_HomeView.hidingUrlForXSeconds
            state.dataSource.detailColor = ConstantsAppColors.urgent
        }
        showsFollowerURLHidingMessage = true
        followerURLHiddenUntil = Date().addingTimeInterval(1 + Double(ConstantsHomeView.hideUrlDuringTimeInSeconds))

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.showsFollowerURLHidingMessage = false
            self.updateState { state in
                state.dataSource.detail = ""
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1 + Double(ConstantsHomeView.hideUrlDuringTimeInSeconds)) {
            self.followerURLHiddenUntil = nil
            let url = UserDefaults.standard.nightscoutUrl ?? ""
            self.updateState { state in
                state.dataSource.detail = url.count > 36 ? String(url.prefix(33)) + "..." : url
                state.dataSource.detailColor = ConstantsAppColors.dataSourceText
            }
        }
    }

    func landscapeGlucoseState() -> RootHomeGlucoseState {
        let latestReadings = bgReadingsAccessor?.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4) ?? []

        return glucoseState(from: latestReadings)
    }

    // MARK: - Glucose

    private func glucoseState(from latestReadings: [BgReading]) -> RootHomeGlucoseState {
        guard let latestReading = latestReadings.first else { return RootHomeGlucoseState() }

        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let isStale = latestReading.timeStamp < Date(timeIntervalSinceNow: -60 * 11)
        var valueText = latestReading.unitizedString(unitIsMgDl: isMgDl)

        if !isStale && !latestReading.hideSlope {
            valueText += " \(latestReading.slopeArrow())"
        }

        let valueColor: Color
        if isStale {
            valueColor = ConstantsAppColors.disabledText
        } else {
            // Keep range classification in one place so the reading and thresholds are always
            // compared in the same unit before the Home view maps the result to presentation colors.
            switch latestReading.bgRangeDescription() {
            case .urgent:
                valueColor = ConstantsAppColors.urgent
            case .notUrgent:
                valueColor = ConstantsAppColors.warning
            case .inRange:
                valueColor = ConstantsAppColors.normal
            }
        }

        let minutesAgo = max(0, -Int(latestReading.timeStamp.timeIntervalSinceNow) / 60)
        let previousReading = latestReadings.count > 1 ? latestReadings[1] : nil

        return RootHomeGlucoseState(
            valueText: valueText,
            valueColor: valueColor,
            valueHasStrikethrough: isStale,
            minutesText: String(minutesAgo),
            minutesAgoText: "\(minutesAgo == 1 ? Texts_Common.minute : Texts_Common.minutes) \(Texts_HomeView.ago)",
            minutesColor: ConstantsAppColors.primaryText,
            deltaText: latestReading.unitizedDeltaString(previousBgReading: previousReading, showUnit: false, highGranularity: true, mgDl: isMgDl),
            deltaUnitText: isMgDl ? Texts_Common.mgdl : Texts_Common.mmol,
            deltaColor: ConstantsAppColors.primaryText
        )
    }

    // MARK: - Pump and Loop

    func pumpState(
        deviceStatus: NightscoutDeviceStatus?,
        latestSiteChangeDate: Date?,
        referenceDate: Date = .now,
        usesRelativeCageTime: Bool = true,
        defaultTextColor: Color = ConstantsAppColors.primaryText
    ) -> RootHomePumpState {
        let hasRecentData = deviceStatus?.lastCheckedDate != .distantPast
            && (deviceStatus?.createdAt ?? .distantPast) <= referenceDate.addingTimeInterval(60)
            && (deviceStatus?.createdAt ?? .distantPast) > referenceDate.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes)
        let basal = hasRecentData ? deviceStatus?.rate?.round(toDecimalPlaces: 1) : nil
        let reservoirText: String

        if hasRecentData, deviceStatus?.pumpReservoir == ConstantsNightscout.omniPodReservoirFlagNumber {
            reservoirText = "50+ U"
        } else if hasRecentData, let reservoir = deviceStatus?.pumpReservoir {
            reservoirText = "\(reservoir.round(toDecimalPlaces: reservoir < ConstantsHomeView.pumpReservoirUrgent ? 1 : 0).stringWithoutTrailingZeroes) U"
        } else {
            reservoirText = "- U"
        }

        let batteryText = hasRecentData ? deviceStatus?.pumpBatteryPercent.map { "\($0) %" } ?? "- %" : "- %"

        return RootHomePumpState(
            basal: RootHomeMetricState(title: "Basal", value: basal.map { "\($0) U/hr" } ?? "? U/hr", valueColor: defaultTextColor),
            reservoir: RootHomeMetricState(title: Texts_HomeView.pumpReservoir, value: reservoirText, valueColor: hasRecentData ? deviceStatus?.pumpReservoirColor() ?? defaultTextColor : defaultTextColor),
            battery: RootHomeMetricState(title: Texts_HomeView.pumpBattery, value: batteryText, valueColor: hasRecentData ? deviceStatus?.pumpBatteryPercentColor() ?? defaultTextColor : defaultTextColor),
            cage: RootHomeMetricState(
                title: "CAGE",
                value: cageText(latestSiteChangeDate, referenceDate: referenceDate, usesRelativeCageTime: usesRelativeCageTime),
                valueColor: cageColor(latestSiteChangeDate, referenceDate: referenceDate, defaultColor: defaultTextColor)
            )
        )
    }

    func loopState(
        deviceStatus: NightscoutDeviceStatus?,
        referenceDate: Date = .now,
        usesRelativeStatusTime: Bool = true,
        defaultTextColor: Color = ConstantsAppColors.primaryText
    ) -> RootHomeLoopState {
        guard let deviceStatus else { return RootHomeLoopState() }

        let aidStatus = deviceStatus.aidStatus
        let presentation = aidStatus.presentation(referenceDate: referenceDate)
        let uploaderBattery = presentation.hasFreshData && !UserDefaults.standard.isMaster
            ? deviceStatus.uploaderBatteryStatusStyle()
            : nil

        return rootHomeLoopState(
            aidStatus: aidStatus,
            referenceDate: referenceDate,
            usesRelativeStatusTime: usesRelativeStatusTime,
            defaultTextColor: defaultTextColor,
            uploaderBattery: uploaderBattery
        )
    }

    /// Presents CareLink pump activity without pretending it is a Nightscout OS-AID loop record.
    func careLinkLoopState(snapshot: CareLinkStatusSnapshot, referenceDate: Date = .now) -> RootHomeLoopState {
        rootHomeLoopState(aidStatus: snapshot.aidStatus, referenceDate: referenceDate)
    }

    /// Applies source capabilities after a status has been selected for the historical strip.
    ///
    /// Historical CareLink pump activity is stored in the shared Nightscout-shaped device-status
    /// model. That normalized model presents itself as a Loop status and would otherwise restore
    /// the COB field. The resolved analytics source remains authoritative because it describes
    /// whether the provider supplies calculated active carbohydrates. Applying the capability to
    /// the completed view state also covers historical ranges where no device-status record exists.
    func historicalLoopState(
        _ loopState: RootHomeLoopState,
        aidAnalyticsSource: AIDAnalyticsSource?
    ) -> RootHomeLoopState {
        var loopState = loopState
        loopState.isHistorical = true

        if let aidAnalyticsSource {
            loopState.showsCOB = loopState.showsCOB && aidAnalyticsSource.supportsCOB
        }

        return loopState
    }

    private func rootHomeLoopState(
        aidStatus: AIDStatus,
        referenceDate: Date,
        usesRelativeStatusTime: Bool = true,
        defaultTextColor: Color = ConstantsAppColors.primaryText,
        uploaderBattery: (systemImage: String, color: Color)? = nil
    ) -> RootHomeLoopState {
        let presentation = aidStatus.presentation(referenceDate: referenceDate)
        let statusTimeAgo: String

        if presentation.showsActivityAge, let lastActivityAt = aidStatus.lastActivityAt {
            statusTimeAgo = usesRelativeStatusTime
                ? lastActivityAt.daysAndHoursAgo()
                : lastActivityAt.formatted(date: .omitted, time: .shortened)
        } else if presentation.showsActivityAge {
            statusTimeAgo = "-m"
        } else {
            statusTimeAgo = ""
        }

        return RootHomeLoopState(
            iob: RootHomeMetricState(
                title: "IOB",
                value: presentation.hasFreshData ? aidStatus.iob.map { "\($0.round(toDecimalPlaces: 2)) U" } ?? "- U" : "- U",
                valueColor: defaultTextColor
            ),
            cob: RootHomeMetricState(
                title: "COB",
                value: presentation.hasFreshData ? "\(aidStatus.cob?.round(toDecimalPlaces: 0).stringWithoutTrailingZeroes ?? "-") g" : "- g",
                valueColor: defaultTextColor
            ),
            // CareLink exposes entered meal grams, not a decaying active-carb value. Keep the
            // metric for Nightscout loops, whose device status contains algorithm-calculated COB.
            showsCOB: aidStatus.supportsCOB,
            statusTitle: presentation.title,
            statusSystemImage: presentation.systemImage,
            statusColor: presentation.color,
            statusTimeAgo: statusTimeAgo,
            showsStatusTimeAgo: !statusTimeAgo.isEmpty,
            showsActivityIndicator: presentation.showsActivityIndicator,
            showsUploaderBattery: uploaderBattery != nil,
            uploaderBatterySystemImage: uploaderBattery?.systemImage ?? "battery.75",
            uploaderBatteryColor: uploaderBattery?.color ?? defaultTextColor
        )
    }

    private func cageText(_ siteChangeDate: Date?, referenceDate: Date, usesRelativeCageTime: Bool) -> String {
        guard let siteChangeDate else { return "-" }
        guard !usesRelativeCageTime else { return siteChangeDate.daysAndHoursAgo() }

        return max(0, referenceDate.timeIntervalSince(siteChangeDate).minutes).minutesToDaysAndHours()
    }

    private func cageColor(_ siteChangeDate: Date?, referenceDate: Date = .now, defaultColor: Color = ConstantsAppColors.primaryText) -> Color {
        guard let siteChangeDate else { return defaultColor }

        let maximumAge = TimeInterval(UserDefaults.standard.CAGEMaxHours * 60 * 60)
        let currentAge = referenceDate.timeIntervalSince(siteChangeDate)

        if currentAge > maximumAge {
            return ConstantsAppColors.urgent
        } else if currentAge > maximumAge - ConstantsHomeView.CAGEUrgentTimeIntervalBeforeMaxHours {
            return ConstantsAppColors.caution
        } else if currentAge > maximumAge - ConstantsHomeView.CAGEWarningTimeIntervalBeforeMaxHours {
            return ConstantsAppColors.warning
        }

        return defaultColor
    }

    // MARK: - Sensor and Data Source

    private func sensorState(activeSensor: Sensor?, cgmTransmitter: CGMTransmitter?) -> RootHomeSensorState {
        let sensorStartDate = activeSensor?.startDate ?? UserDefaults.standard.activeSensorStartDate
        let maximumAgeInDays = cgmTransmitter?.maxSensorAgeInDays() ?? UserDefaults.standard.activeSensorMaxSensorAgeInDays ?? 0
        let maximumAgeInMinutes = maximumAgeInDays * 24 * 60

        guard let sensorStartDate, maximumAgeInMinutes > 0 else { return RootHomeSensorState() }

        let sensorAgeInMinutes = Double(Calendar.current.dateComponents([.minute], from: sensorStartDate, to: Date()).minute ?? 0)
        let timeLeftInMinutes = maximumAgeInMinutes - sensorAgeInMinutes
        let description = UserDefaults.standard.activeSensorDescription ?? cgmTransmitter?.cgmTransmitterType().detailedDescription() ?? ""
        let sensorType = cgmTransmitter?.cgmTransmitterType().sensorType()
        let warmUpMinutes: Double?

        if !UserDefaults.standard.isMaster,
           UserDefaults.standard.followerDataSourceType == .libreLinkUp,
           sensorAgeInMinutes < ConstantsLibreLinkUp.sensorWarmUpRequiredInMinutesForLibre {
            warmUpMinutes = ConstantsLibreLinkUp.sensorWarmUpRequiredInMinutesForLibre
        } else if UserDefaults.standard.isMaster,
                  sensorType == .Libre,
                  sensorAgeInMinutes < ConstantsMaster.minimumSensorWarmUpRequiredInMinutes {
            warmUpMinutes = ConstantsMaster.minimumSensorWarmUpRequiredInMinutes
        } else if UserDefaults.standard.isMaster,
                  cgmTransmitter?.cgmTransmitterType() == .dexcomG7 {
            let requiredMinutes = ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG7
            warmUpMinutes = sensorAgeInMinutes < requiredMinutes ? requiredMinutes : nil
        } else if UserDefaults.standard.isMaster, sensorType == .Dexcom {
            let requiredMinutes = cgmTransmitter?.isAnubisG6() == true
                ? ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG6Anubis
                : ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6
            warmUpMinutes = sensorAgeInMinutes < requiredMinutes ? requiredMinutes : nil
        } else {
            warmUpMinutes = nil
        }

        let currentAge: String
        let maximumAge: String
        let countsDown = UserDefaults.standard.preferSensorCountdown
        if let warmUpMinutes {
            currentAge = ""
            let readyDate = sensorStartDate.addingTimeInterval(warmUpMinutes * 60)
            maximumAge = "\(Texts_BluetoothPeripheralView.warmingUpUntil) \(readyDate.toStringInUserLocale(timeStyle: .short, dateStyle: .none))"
        } else {
            currentAge = countsDown
                ? Texts_HomeView.sensorLifetimeRemaining(max(timeLeftInMinutes, 0).minutesToDaysAndHours())
                : sensorStartDate.daysAndHoursAgo()
            maximumAge = " / \(maximumAgeInMinutes.minutesToDaysAndHours())"
        }

        return RootHomeSensorState(
            title: description + (cgmTransmitter?.isAnubisG6() == true ? " (Anubis)" : ""),
            currentAge: currentAge,
            maxAge: maximumAge,
            currentAgeColor: sensorAgeColor(timeLeftInMinutes: timeLeftInMinutes),
            progressColor: ConstantsAppColors.sensorProgress,
            progress: min(max(countsDown ? timeLeftInMinutes / maximumAgeInMinutes : 1 - (timeLeftInMinutes / maximumAgeInMinutes), 0), 1),
            countsDown: countsDown
        )
    }

    private func dataSourceState(
        sensorState: RootHomeSensorState,
        activeSensor: Sensor?,
        cgmTransmitter: CGMTransmitter?,
        connectionStatus: BluetoothPeripheralDisplayStatus?
    ) -> RootHomeDataSourceState {
        let isMaster = UserDefaults.standard.isMaster
        var title = sensorState.title
        var detail = sensorState.maxAge
        var detailColor = ConstantsAppColors.dataSourceText
        var detailSystemImage: String?
        var detailSystemImageColor = ConstantsAppColors.secondaryText
        var detailSystemImageAccessibilityLabel = ""

        if isMaster, sensorState.title.isEmpty {
            if cgmTransmitter?.cgmTransmitterType().sensorType() == .Libre, activeSensor?.startDate != nil {
                title = " ⚠️  " + Texts_HomeView.reconnectLibreDataSource
            } else if cgmTransmitter != nil {
                switch connectionStatus {
                case .some(.connected):
                    title = " ⏳  " + Texts_HomeView.waitingForDataSource
                case .some(.waitingForNextReading):
                    title = " ⏳  " + Texts_BluetoothPeripheralView.waiting
                case .some(.reconnecting):
                    title = " ⏳  " + Texts_HomeView.reconnectingToCGM
                case .some(.discovering), .some(.connecting), .some(.notScanning), .none:
                    title = " ⏳  " + Texts_HomeView.connectingToCGM
                }
            } else {
                title = " ⚠️  " + Texts_HomeView.noDataSourceConnected
            }
        } else if !isMaster {
            title = UserDefaults.standard.followerDataSourceType.description

            switch UserDefaults.standard.followerDataSourceType {
            case .nightscout:
                if let hiddenUntil = followerURLHiddenUntil, hiddenUntil > Date() {
                    detail = showsFollowerURLHidingMessage ? Texts_HomeView.hidingUrlForXSeconds : ""
                    detailColor = showsFollowerURLHidingMessage ? ConstantsAppColors.urgent : ConstantsAppColors.dataSourceText
                } else if !UserDefaults.standard.nightscoutEnabled {
                    detail = Texts_HomeView.nightscoutNotEnabled
                    detailColor = ConstantsAppColors.urgent
                } else if UserDefaults.standard.nightscoutUrl == nil {
                    detail = Texts_HomeView.nightscoutURLMissing
                    detailColor = ConstantsAppColors.urgent
                } else if let patientName = UserDefaults.standard.followerPatientName {
                    detail = patientName
                } else {
                    let url = UserDefaults.standard.nightscoutUrl ?? ""
                    detail = url.count > 36 ? String(url.prefix(33)) + "..." : url
                }
            case .libreLinkUp, .libreLinkUpRussia:
                if UserDefaults.standard.libreLinkUpEmail == nil || UserDefaults.standard.libreLinkUpPassword == nil {
                    detail = Texts_HomeView.followerAccountCredentialsMissing
                    detailColor = ConstantsAppColors.urgent
                } else if UserDefaults.standard.libreLinkUpPreventLogin {
                    detail = Texts_HomeView.followerAccountCredentialsInvalid
                    detailColor = ConstantsAppColors.urgent
                } else {
                    detail = UserDefaults.standard.followerPatientName ?? ""
                }
            case .medtrumEasyView:
                if UserDefaults.standard.medtrumEasyViewEmail == nil || UserDefaults.standard.medtrumEasyViewPassword == nil {
                    detail = Texts_HomeView.followerAccountCredentialsMissing
                    detailColor = ConstantsAppColors.urgent
                } else if UserDefaults.standard.medtrumEasyViewPreventLogin {
                    detail = Texts_HomeView.followerAccountCredentialsInvalid
                    detailColor = ConstantsAppColors.urgent
                } else {
                    detail = UserDefaults.standard.followerPatientName ?? ""
                }
            case .dexcomShare:
                if UserDefaults.standard.dexcomShareAccountName == nil || UserDefaults.standard.dexcomSharePassword == nil {
                    detail = Texts_HomeView.followerAccountCredentialsMissing
                    detailColor = ConstantsAppColors.urgent
                } else if UserDefaults.standard.dexcomShareRegion == .none {
                    detail = Texts_HomeView.followerAccountCredentialsInvalid
                    detailColor = ConstantsAppColors.urgent
                } else {
                    detail = UserDefaults.standard.followerPatientName ?? ""
                }
            case .calendar:
                if UserDefaults.standard.calendarFollowCalendarId == nil {
                    detail = Texts_SettingsView.valueIsRequired
                    detailColor = ConstantsAppColors.urgent
                } else {
                    detail = UserDefaults.standard.followerPatientName ?? UserDefaults.standard.calendarFollowCalendarId ?? ""
                }
            case .careLink:
                // CareLink exposes a native observable state instead of a public status-page API.
                let snapshot = CareLinkAccountState.shared.snapshot
                let patientName = snapshot.selectedPatient?.displayName ?? snapshot.metadata.patientName
                let showsPatient = snapshot.status == .active || snapshot.status == .connecting && patientName != nil
                if showsPatient {
                    detail = patientName ?? ""
                    if let remainingMinutes = snapshot.metadata.sensorRemainingMinutes {
                        let indicator = ConstantsHomeView.careLinkSensorIndicator(remainingMinutes: remainingMinutes)
                        detailSystemImage = indicator.systemImage
                        detailSystemImageColor = indicator.color
                        detailSystemImageAccessibilityLabel = Texts_HomeView.sensorLifetimeRemaining(Double(remainingMinutes).minutesToDaysAndHours())
                    }
                } else {
                    detail = snapshot.status.title
                    if snapshot.status != .connecting {
                        detailColor = snapshot.status.indicatorColor
                    }
                }
            }
        }

        return RootHomeDataSourceState(
            title: title,
            detail: detail,
            detailColor: detailColor,
            detailSystemImage: detailSystemImage,
            detailSystemImageColor: detailSystemImageColor,
            detailSystemImageAccessibilityLabel: detailSystemImageAccessibilityLabel,
            showsConnectionIcon: !isMaster,
            connectionColor: followerConnectionColor,
            showsKeepAliveIcon: !isMaster,
            keepAliveSystemImage: UserDefaults.standard.followerBackgroundKeepAliveType.keepAliveImageString,
            keepAliveColor: followerKeepAliveColor
        )
    }

    private func sensorAgeColor(timeLeftInMinutes: Double) -> Color {
        if timeLeftInMinutes < 0 {
            return ConstantsAppColors.sensorExpired
        } else if timeLeftInMinutes <= ConstantsHomeView.sensorProgressViewUrgentInMinutes {
            return ConstantsAppColors.sensorUrgent
        } else if timeLeftInMinutes <= ConstantsHomeView.sensorProgressViewWarningInMinutes {
            return ConstantsAppColors.sensorWarning
        }

        return ConstantsAppColors.sensorText
    }

    private func sensorNoiseState(activeSensor: Sensor?) -> RootHomeSensorNoiseState {
        guard UserDefaults.standard.isMaster,
              UserDefaults.standard.showSensorNoise,
              let activeSensor,
              activeSensor.noiseAlgorithmVersion == ConstantsSensorNoise.algorithmVersion,
              let latestReadingAt = activeSensor.noiseLatestReadingAt
        else {
            return RootHomeSensorNoiseState()
        }

        let readingAge = Date().timeIntervalSince(latestReadingAt)
        guard readingAge >= -TimeInterval(minutes: 5),
              readingAge <= ConstantsSensorNoise.rootWarningFreshness else {
            return RootHomeSensorNoiseState()
        }

        let rawState = SensorNoiseState(rawValue: activeSensor.noiseStateRaw) ?? .collecting
        let sensitivity = UserDefaults.standard.sensorNoiseSensitivity
        let persistedState = ConstantsSensorNoise.displayState(
            rawState: rawState,
            shortTermNoise: activeSensor.shortTermNoise?.doubleValue,
            longTermNoise: activeSensor.longTermNoise?.doubleValue,
            sensitivity: sensitivity
        )
        return RootHomeSensorNoiseState(
            showsIndicator: true,
            indicatorColor: persistedState.displayColor,
            indicatorAccessibilityLabel: Texts_HomeView.sensorManagementNoiseTitle + ": " + persistedState.localizedTitle
        )
    }

    private var followerConnectionIsRecent: Bool {
        guard let lastConnection = UserDefaults.standard.timeStampOfLastFollowerConnection else { return false }

        return lastConnection > Date().addingTimeInterval(-Double(UserDefaults.standard.followerDataSourceType.secondsUntilFollowerDisconnectWarning))
    }

    private var followerConnectionColor: Color {
        // CareLink publishes account and connection state directly. A previous successful reading
        // must not keep Home green after the retained browser session requires a new login.
        if UserDefaults.standard.followerDataSourceType == .careLink {
            return CareLinkAccountState.shared.snapshot.status.indicatorColor
        }

        // Calendar Follow has its own payload status. Use this instead of the
        // generic follower connection timestamp so the Home dot matches Settings.
        if UserDefaults.standard.followerDataSourceType == .calendar {
            switch CalendarShareStatus(rawValue: UserDefaults.standard.calendarFollowStatus) ?? .notConfigured {
            case .active:
                return ConstantsAppColors.normal
            case .waiting:
                return .yellow
            case .noData, .notConfigured:
                return .gray
            case .stale:
                return .orange
            case .error:
                return ConstantsAppColors.urgent
            }
        }

        return followerConnectionIsRecent ? ConstantsAppColors.normal : ConstantsAppColors.urgent
    }

    private var followerKeepAliveColor: Color {
        guard UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat,
              let lastHeartbeat = UserDefaults.standard.timeStampOfLastHeartBeat,
              let warningInterval = UserDefaults.standard.secondsUntilHeartBeatDisconnectWarning
        else {
            return ConstantsAppColors.secondaryText
        }

        return lastHeartbeat > Date().addingTimeInterval(-warningInterval) ? ConstantsAppColors.normal : ConstantsAppColors.urgent
    }

    // MARK: - Visibility and Controls

    private func visibilityState(sensorState: RootHomeSensorState, usesScreenLockNightLayout: Bool) -> RootHomeVisibilityState {
        let dataFlowPolicy = UserDefaults.standard.dataFlowPolicy

        return RootHomeVisibilityState(
            showsPump: dataFlowPolicy.showsPumpData && !usesScreenLockNightLayout,
            showsLoop: dataFlowPolicy.showsTherapyStatus && !usesScreenLockNightLayout,
            showsMiniChart: UserDefaults.standard.showMiniChart && !usesScreenLockNightLayout,
            showsStatistics: UserDefaults.standard.showStatistics && !usesScreenLockNightLayout,
            showsSensor: !sensorState.maxAge.isEmpty && !usesScreenLockNightLayout,
            showsDataSource: !usesScreenLockNightLayout,
            showsClock: usesScreenLockNightLayout && UserDefaults.standard.showClockWhenScreenIsLocked
        )
    }

    private func controlsState(alertManager: AlertManager?, bgPostProcessingManager: BgPostProcessingManager?) -> RootHomeControlsState {
        RootHomeControlsState(
            statisticsDays: UserDefaults.standard.daysToUseStatistics,
            clockText: state.controls.clockText,
            sensorButtonEnabled: UserDefaults.standard.isMaster,
            postProcessingSystemImage: postProcessingSystemImage(bgPostProcessingManager: bgPostProcessingManager),
            postProcessingEnabled: UserDefaults.standard.enableAdjustment || UserDefaults.standard.enableSmoothing,
            snoozeSystemImage: snoozeSystemImage(alertManager: alertManager)
        )
    }

    private func postProcessingSystemImage(bgPostProcessingManager: BgPostProcessingManager?) -> String {
        let symbolBaseName: String

        if !UserDefaults.standard.enableAdjustment {
            symbolBaseName = "dial.low"
        } else if let adjustment = bgPostProcessingManager?.latestActiveBgAdjustment(), adjustment.slope.round(toDecimalPlaces: 2) != 1 {
            symbolBaseName = "dial.high"
        } else {
            symbolBaseName = "dial.medium"
        }

        return UserDefaults.standard.enableSmoothing ? symbolBaseName + ".fill" : symbolBaseName
    }

    private func snoozeSystemImage(alertManager: AlertManager?) -> String {
        switch alertManager?.snoozeStatus() {
        case .allSnoozed:
            return "speaker.slash.fill"
        case .urgent, .notUrgent:
            return "speaker.slash"
        default:
            return "speaker.wave.2"
        }
    }

    // MARK: - Publishing

    private func updateState(_ update: @escaping (inout RootHomeState) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.updateState(update)
            }

            return
        }

        var newState = state
        update(&newState)
        publish(newState)
    }

    private func publish(_ state: RootHomeState) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            self.state = state
        }
    }

    private func formattedLimit(_ value: Double, isMgDl: Bool) -> String {
        value.bgValueToString(mgDl: isMgDl)
    }

}

// MARK: - View Actions

/// Commands emitted by controls in the SwiftUI home screen.
///
/// RootTabView supplies navigation and presentation commands. The remaining service commands are
/// supplied by RootApplicationCoordinator while its presentation responsibilities are extracted.
struct RootHomeActions {
    var showSnooze: () -> Void = {}
    var queueSensorHealthTest: (SensorHealthTestKind) -> Void = { _ in }
    var showBgReadings: () -> Void = {}
    var showSensorManagement: () -> Void = {}
    var showCalibration: () -> Void = {}
    var showBgAdjustments: () -> Void = {}
    var toolbarLongPressActivated: () -> Void = {}
    var showHideItems: () -> Void = {}
    var toggleScreenLock: () -> Void = {}
    var keepScreenAwake: () -> Void = {}
    var refreshPumpAndLoopStatus: () -> Void = {}
    var statisticsDaysChanged: (Int) -> Void = { _ in }
    var cycleStatisticsType: () -> Void = {}
    var hideFollowerUrl: () -> Void = {}
    var showAIDStatus: () -> Void = {}
    var showBluetooth: () -> Void = {}
}
