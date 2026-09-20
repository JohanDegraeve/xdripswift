//
//  TherapyMetricsSettingsView.swift
//  xdrip
//
//  Created by Paul Plant on 12/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Treatment settings and local-estimate explanations use the existing SettingsViews table.
enum TherapyTexts {
    static func text(_ key: String) -> String { NSLocalizedString("therapy." + key, tableName: "SettingsViews", comment: "") }
}

struct TreatmentSettingsView: View {
    @StateObject private var presenter = SettingsActionPresenter(router: SettingsRouter())

    var body: some View {
        SettingsScreenDestinationView(settingsScreen: TreatmentSettingsViewModel.screen, presenter: presenter)
    }
}

struct TreatmentSettingsViewModel: SettingsNativeSectionProvider {
    enum Group { case insulin, carbs }
    let group: Group
    var policyProvider: () -> DataFlowPolicy = { UserDefaults.standard.dataFlowPolicy }

    static var screen: SettingsScreen {
        SettingsScreen(title: TherapyTexts.text("treatmentSettings"),
                       introduction: { TreatmentSettingsViewModel(group: .insulin).introduction }, onlineHelpTopic: .treatments,
                       providers: { [.insulin, .carbs].map { TreatmentSettingsViewModel(group: $0) } })
    }

    private var policy: DataFlowPolicy { policyProvider() }

    private var introduction: String {
        if let source = policy.externalIOBSource, policy.externalCOBSource == source {
            return String(format: TherapyTexts.text("settingsExternal"), providerName(source))
        } else if let source = policy.externalIOBSource {
            return String(format: TherapyTexts.text("settingsMixed"), providerName(source))
        }
        return TherapyTexts.text("settingsLocal")
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let isInsulin = group == .insulin
        if (isInsulin ? policy.externalIOBSource : policy.externalCOBSource) != nil {
            return [SettingsRow(id: isInsulin ? "treatments.insulinType" : "treatments.carbDuration",
                title: TherapyTexts.text(isInsulin ? "insulinType" : "carbDuration"),
                detail: TherapyTexts.text("automatic"), accessory: .none, isEnabled: false)]
        }
        var rows: [SettingsRow] = []
        if isInsulin {
            rows.append(SettingsRow(id: "treatments.insulinType", title: TherapyTexts.text("insulinType"),
                accessory: .none, control: .menu(options: {
                    let selected = TherapyModelSettings(defaults: .standard).insulinPeak
                    return TherapyInsulinPreset.allCases.map {
                        SettingsMenuOption(title: $0.rawValue, isSelected: $0.peak == selected)
                    }
                }, selectOption: { index in
                    let presets = TherapyInsulinPreset.allCases
                    guard presets.indices.contains(index) else { return }
                    UserDefaults.standard.set(presets[index].peak, forKey: "localInsulinPeak")
                })))
        }
        else {
            rows.append(SettingsRow(id: "treatments.carbDuration", title: TherapyTexts.text("carbDuration"),
                accessory: .none, control: .menu(options: {
                    let selected = TherapyModelSettings(defaults: .standard).carbDuration
                    return TherapyModelSettings.carbDurationChoices.map {
                        SettingsMenuOption(title: Self.durationText($0), isSelected: $0 == selected)
                    }
                }, selectOption: { index in
                    let durations = TherapyModelSettings.carbDurationChoices
                    guard durations.indices.contains(index) else { return }
                    UserDefaults.standard.set(durations[index], forKey: "localCarbDuration")
                })))
        }
        return rows
    }

    private func providerName(_ source: TherapyMetricSource) -> String {
        source == .careLink ? "CareLink" : policy.nightscoutFollowType.description
    }

    private static func durationText(_ minutes: Double) -> String {
        DateComponentsFormatter.localizedString(from: DateComponents(hour: Int(minutes / 60)), unitsStyle: .full) ?? ""
    }

    func sectionTitle() -> String? { nil }
    func sectionFooter() -> String? {
        let settings = TherapyModelSettings(defaults: .standard)
        switch group {
        case .insulin:
            guard policy.externalIOBSource == nil else { return nil }
            return String(format: TherapyTexts.text("insulinModel"),
                TherapyInsulinPreset.nearest(to: settings.insulinPeak).rawValue,
                Self.durationText(settings.insulinDuration),
                DateComponentsFormatter.localizedString(from: DateComponents(minute: Int(settings.insulinPeak)), unitsStyle: .full) ?? "")
        case .carbs:
            guard policy.externalCOBSource == nil else { return nil }
            let key = settings.carbDuration <= 180 ? "carbFast" : settings.carbDuration <= 360 ? "carbNormal" : "carbLong"
            return TherapyTexts.text(key)
        }
    }
    private func row(at index: Int) -> SettingsRow? {
        let rows = settingsRows(sectionID: 0)
        return rows.indices.contains(index) ? rows[index] : nil
    }
    func settingsRowText(index: Int) -> String { row(at: index)?.title ?? "" }
    func accessoryType(index: Int) -> SettingsAccessory { .none }
    func detailedText(index: Int) -> String? { row(at: index)?.detail }
    func numberOfRows() -> Int { settingsRows(sectionID: 0).count }
    func onRowSelect(index: Int) -> SettingsSelectedRowAction { .nothing }
    func isEnabled(index: Int) -> Bool { row(at: index)?.isEnabled ?? false }
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
}

struct TherapyMetricDetailsView: View {
    let metric: TherapyMetricState
    let isIOB: Bool
    var body: some View {
        List {
            Section {
                Text(metric.formatted(isIOB: isIOB, at: metric.referenceDate)).font(.title2)
                Text(TherapyTexts.text("local"))
                Text(metric.referenceDate.formatted(date: .abbreviated, time: .shortened))
                let settings = TherapyModelSettings(defaults: .standard)
                if isIOB {
                    LabeledContent(TherapyTexts.text("insulinType"), value: TherapyInsulinPreset.nearest(to: settings.insulinPeak).rawValue)
                } else {
                    LabeledContent(TherapyTexts.text("carbDuration"), value: DateComponentsFormatter.localizedString(from: DateComponents(hour: Int(settings.carbDuration / 60)), unitsStyle: .full) ?? "")
                }
            }
            Section {
                NavigationLink(TherapyTexts.text("treatmentSettings")) { TreatmentSettingsView() }
                Text(TherapyTexts.text("settingsHelp"))
            }
        }
        .navigationTitle(isIOB ? "IOB" : "COB")
    }
}
