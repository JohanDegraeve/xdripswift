//
//  CareLinkPumpStatusView.swift
//  xdripswift
//
//  Created by Paul Plant on 3/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Shows the CareLink pump state behind the compact Home therapy strip.
/// The screen mirrors the visual hierarchy of AID status without describing pump telemetry as a loop.
struct CareLinkPumpStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var state = CareLinkAccountState.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                List {
                    therapySection
                    // CareLink also uses its medical-device fields for sensor-only accounts. Do not
                    // turn those fields into a Pump or Reported Limits section without pump evidence.
                    if pump.isReported {
                        pumpSection
                    }
                    communicationSection
                    if hasReportedLimits {
                        limitsSection
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(ConstantsAppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle("CareLink")
            .toolbarBackground(ConstantsAppColors.groupedBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) { dismiss() }
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_SettingsView.followerRefresh) { state.refresh() }
                        .foregroundStyle(ConstantsAppColors.toolbarAction)
                }
            }
        }
        .colorScheme(.dark)
    }

    private var header: some View {
        AIDStatusBanner(
            systemName: "Medtronic",
            detail: deviceName,
            statusTitle: statusTitle,
            statusColor: statusColor,
            backgroundColor: statusColor.opacity(ConstantsHomeView.AIDStatusBannerBackgroundOpacity)
        ) {
            Image(systemName: "cross.case.fill")
                .font(.title2)
                .foregroundStyle(ConstantsAppColors.primaryText)
        } statusIcon: {
            AIDStatusSymbolImage(symbol: statusSymbol)
        }
    }

    private var therapySection: some View {
        Section(Texts_SettingsView.careLinkTherapy) {
            // IOB remains useful without a pump. Every other therapy row describes pump delivery.
            if pump.isReported {
                row(Texts_SettingsView.careLinkDelivery, readable(pump.algorithmState))
                row(Texts_SettingsView.careLinkReadiness, readable(pump.algorithmReadiness))
                row(Texts_SettingsView.careLinkLowGlucoseSuspend, readable(pump.lowGlucoseSuspendState))
            }
            row(Texts_SettingsView.careLinkActiveInsulin, units(pump.activeInsulin))
            if pump.isReported {
                row(Texts_SettingsView.careLinkBasalRate, rate(pump.currentBasalRate))
            }
            if let remainingMinutes = snapshot.metadata.sensorRemainingMinutes {
                row(
                    Texts_SettingsView.careLinkSensorRemaining,
                    Double(remainingMinutes).minutesToDaysAndHours(),
                    indicator: ConstantsHomeView.careLinkSensorIndicator(remainingMinutes: remainingMinutes)
                )
            }
            if pump.isReported {
                row(Texts_SettingsView.careLinkLastPumpUpdate, formatted(pump.observedAt ?? pump.lastDataUpdateAt))
            }
        }
    }

    private var pumpSection: some View {
        Section(Texts_SettingsView.careLinkPump) {
            row(Texts_SettingsView.careLinkModel, deviceName)
            row(Texts_SettingsView.careLinkStatus, pump.pumpStatusTitle)
            row(
                Texts_SettingsView.careLinkBattery,
                pump.batteryPercent.map { "\($0) %" },
                indicator: ConstantsHomeView.batteryIndicator(percent: pump.batteryPercent)
            )
            row(Texts_SettingsView.careLinkReservoir, units(pump.reservoirUnits))
        }
    }

    private var communicationSection: some View {
        Section(Texts_SettingsView.careLinkCommunication) {
            // The conduit range flag refers to the sensor when no pump is present, so keep only the
            // CareLink service check and route in that case.
            if pump.isReported {
                row(Texts_SettingsView.careLinkPumpConnected, yesNo(pump.isCommunicating))
                row(Texts_SettingsView.careLinkPumpInRange, yesNo(pump.isInRange))
            }
            row(Texts_SettingsView.careLinkLastCareLinkCheck, formatted(snapshot.lastCheckAt))
            row(Texts_SettingsView.careLinkDataRoute, snapshot.metadata.route?.rawValue.capitalized)
        }
    }

    private var limitsSection: some View {
        Section(Texts_SettingsView.careLinkReportedLimits) {
            row(Texts_SettingsView.careLinkMaximumAutoBasal, rate(pump.maximumAutoBasalRate))
            row(Texts_SettingsView.careLinkMaximumBolus, units(pump.maximumBolusAmount))
        }
    }

    private var snapshot: CareLinkStatusSnapshot { state.snapshot }
    private var pump: CareLinkPumpSnapshot { snapshot.pump }

    private var deviceName: String {
        [snapshot.metadata.deviceFamily, snapshot.metadata.deviceModel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var statusTitle: String {
        // The shared IOB presentation supplies OK/No Data from freshness without inventing a pump
        // connection status for an account that has not reported one.
        if !pump.isReported {
            return snapshot.aidStatus?.presentation().title ?? snapshot.status.title
        }
        if pump.isSuspended == true { return Texts_SettingsView.careLinkSuspended }
        if pump.isCommunicating == false || pump.isInRange == false { return Texts_SettingsView.careLinkDisconnected }
        if snapshot.status == .connecting {
            return hasPumpData ? readable(pump.algorithmState) ?? Texts_SettingsView.careLinkActive : Texts_Common.checking
        }
        return snapshot.status.title
    }

    /// Keep the pump detail banner's existing state selection, but use the common symbol definitions.
    /// The shared renderer applies the circle weight and preserves the shield and triangle styling.
    private var statusSymbol: AIDStatusSymbol {
        // Keep the same freshness symbol used by Home, Watch, widgets and Live Activity.
        if !pump.isReported {
            return snapshot.aidStatus?.presentation().symbol ?? .pump
        }
        if pump.isSuspended == true { return .suspended }
        if pump.isCommunicating == false || pump.isInRange == false { return .disconnected }
        return pump.reportsActiveSmartGuard ? .smartGuard : .pump
    }

    private var statusColor: Color {
        // Color is the only state change for non-pump IOB: green, yellow and red reflect its age.
        if !pump.isReported {
            return snapshot.aidStatus?.presentation().color ?? snapshot.status.indicatorColor
        }
        if pump.isSuspended == true { return ConstantsAppColors.warning }
        if pump.isCommunicating == false || pump.isInRange == false { return ConstantsAppColors.urgent }
        if snapshot.status == .connecting {
            return hasPumpData ? ConstantsAppColors.normal : ConstantsAppColors.secondaryText
        }
        return snapshot.status.indicatorColor
    }

    private var hasPumpData: Bool {
        pump.isReported && (pump.observedAt != nil || pump.lastDataUpdateAt != nil)
    }

    /// Do not show an empty limits section merely because some other pump telemetry is present.
    private var hasReportedLimits: Bool {
        pump.isReported && (pump.maximumAutoBasalRate != nil || pump.maximumBolusAmount != nil)
    }

    private func row(_ title: String, _ value: String?, indicator: StatusSymbolPresentation? = nil) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            HStack(spacing: 5) {
                if let indicator {
                    Image(systemName: indicator.systemImage)
                        .foregroundStyle(indicator.color)
                        .fixedSize()
                        .accessibilityHidden(true)
                }
                Text(value?.isEmpty == false ? value! : "-")
                    .foregroundStyle(ConstantsAppColors.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func formatted(_ date: Date?) -> String? {
        date.map { "\($0.formatted(date: .omitted, time: .shortened)) (\($0.daysAndHoursAgo(appendAgo: true)))" }
    }

    private func units(_ value: Double?) -> String? {
        value.map { "\($0.round(toDecimalPlaces: 2).stringWithoutTrailingZeroes) U" }
    }

    private func rate(_ value: Double?) -> String? {
        value.map { "\($0.round(toDecimalPlaces: 2).stringWithoutTrailingZeroes) U/hr" }
    }

    private func yesNo(_ value: Bool?) -> String? {
        value.map { $0 ? Texts_Common.yes : Texts_Common.no }
    }

    private func readable(_ value: String?) -> String? {
        value?.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
