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
                    pumpSection
                    communicationSection
                    limitsSection
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
        HStack(spacing: 10) {
            Image(systemName: "cross.case.fill")
                .font(.title2)
                .foregroundStyle(ConstantsAppColors.primaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Medtronic")
                    .font(.title2.bold())
                Text(deviceName)
                    .font(.callout.bold())
                    .foregroundStyle(ConstantsAppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)
            }
            Spacer()
            Image(systemName: statusImage)
                .font(.title3.bold())
                .foregroundStyle(statusColor)
            Text(statusTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .layoutPriority(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(statusColor.opacity(ConstantsHomeView.AIDStatusBannerBackgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var therapySection: some View {
        Section(Texts_SettingsView.careLinkTherapy) {
            row(Texts_SettingsView.careLinkDelivery, readable(pump.algorithmState))
            row(Texts_SettingsView.careLinkReadiness, readable(pump.algorithmReadiness))
            row(Texts_SettingsView.careLinkLowGlucoseSuspend, readable(pump.lowGlucoseSuspendState))
            row(Texts_SettingsView.careLinkActiveInsulin, units(pump.activeInsulin))
            row(Texts_SettingsView.careLinkBasalRate, rate(pump.currentBasalRate))
            if let remainingMinutes = snapshot.metadata.sensorRemainingMinutes {
                row(Texts_SettingsView.careLinkSensorRemaining, Double(remainingMinutes).minutesToDaysAndHours())
            }
            row(Texts_SettingsView.careLinkLastPumpUpdate, formatted(pump.observedAt ?? pump.lastDataUpdateAt))
        }
    }

    private var pumpSection: some View {
        Section(Texts_SettingsView.careLinkPump) {
            row(Texts_SettingsView.careLinkModel, deviceName)
            row(Texts_SettingsView.careLinkStatus, pump.pumpStatusTitle)
            row(Texts_SettingsView.careLinkBattery, pump.batteryPercent.map { "\($0) %" })
            row(Texts_SettingsView.careLinkReservoir, units(pump.reservoirUnits))
        }
    }

    private var communicationSection: some View {
        Section(Texts_SettingsView.careLinkCommunication) {
            row(Texts_SettingsView.careLinkPumpConnected, yesNo(pump.isCommunicating))
            row(Texts_SettingsView.careLinkPumpInRange, yesNo(pump.isInRange))
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
        if pump.isSuspended == true { return Texts_SettingsView.careLinkSuspended }
        if pump.isCommunicating == false || pump.isInRange == false { return Texts_SettingsView.careLinkDisconnected }
        if snapshot.status == .connecting {
            return hasPumpData ? readable(pump.algorithmState) ?? Texts_SettingsView.careLinkActive : Texts_Common.checking
        }
        return snapshot.status.title
    }

    private var statusImage: String {
        if pump.isSuspended == true { return "pause.circle.fill" }
        if pump.isCommunicating == false || pump.isInRange == false { return "exclamationmark.triangle.fill" }
        return pump.reportsActiveSmartGuard ? "shield.lefthalf.filled" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if pump.isSuspended == true { return ConstantsAppColors.warning }
        if pump.isCommunicating == false || pump.isInRange == false { return ConstantsAppColors.urgent }
        if snapshot.status == .connecting {
            return hasPumpData ? ConstantsAppColors.normal : ConstantsAppColors.secondaryText
        }
        return snapshot.status.indicatorColor
    }

    private var hasPumpData: Bool {
        pump.observedAt != nil || pump.lastDataUpdateAt != nil
    }

    private func row(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Text(value?.isEmpty == false ? value! : "-")
                .foregroundStyle(ConstantsAppColors.secondaryText)
                .multilineTextAlignment(.trailing)
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
