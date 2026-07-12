//
//  SnoozeView.swift
//  xdrip
//
//  Created by Paul Plant on 13/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

// ported into SwiftUI from the old storyboard-based Snooze view controller
struct SnoozeView: View {
    @StateObject private var viewModel: SnoozeViewModel
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    init(viewModel: SnoozeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Keep the all-snoozed illustration out of the List
                contentList()
                
                if viewModel.showAllSnoozedImage {
                    allSnoozedPlaceholderView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(Texts_HomeView.snoozeButton)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                viewModel.refresh()
            }
        }
        .colorScheme(.dark)
        .sheet(item: $viewModel.pickerData) { pickerData in
            SnoozePickerView(pickerData: pickerData)
        }
        .onDisappear {
            UserDefaults.standard.updateSnoozeStatus.toggle()
        }
    }
    
    @ViewBuilder private func contentList() -> some View {
        List {
            Section {
                // This replaces snoozeAllUISwitchAction(_:) from SnoozeViewController.
                Toggle(Texts_HomeView.snoozeAllTitle, isOn: Binding(
                    get: { viewModel.snoozeAllSwitchIsOn },
                    set: { isOn in
                        viewModel.handleSnoozeAllToggleChanged(isOn: isOn)
                    }
                ))
                .tint(.red)
                .foregroundStyle(Color(.colorPrimary))
                
                snoozeAllStatusRow()
                    .listRowBackground(snoozeAllStatusBackgroundColor())
            }
            
            if !viewModel.showAllSnoozedImage {
                ForEach(viewModel.rows) { row in
                    Section(header: sectionHeader(title: row.sectionTitle)) {
                        Toggle(isOn: Binding(
                            get: { row.isSnoozed },
                            set: { isOn in
                                viewModel.handleAlertToggleChanged(alertKind: row.alertKind, isOn: isOn)
                            }
                        )) {
                            Text(row.statusText)
                                .foregroundStyle(row.statusTextColor)
                        }
                        .tint(.green)
                        .listRowBackground(row.isSnoozed ? ConstantsUI.warningSectionBackgroundColor : Color(uiColor: .secondarySystemGroupedBackground))
                    }
                }
            }
        }
    }
    
    @ViewBuilder private func snoozeAllStatusRow() -> some View {
        Text(viewModel.bannerText)
            .font(.body.weight(.semibold))
            .foregroundStyle(viewModel.bannerTextColor)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
    }
    
    private func snoozeAllStatusBackgroundColor() -> Color {
        // Match the shared warning tint used elsewhere when everything is snoozed.
        if viewModel.showAllSnoozedImage {
            return ConstantsUI.warningSectionBackgroundColor
        }
        
        return viewModel.bannerBackgroundColor
    }
    
    @ViewBuilder private func sectionHeader(title: String) -> some View {
        Text(title)
            .foregroundStyle(ConstantsUI.sectionHeaderColor)
    }
    
    @ViewBuilder private func allSnoozedPlaceholderView() -> some View {
        HStack {
            Spacer()
            
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 180))
                .foregroundStyle(Color.red.opacity(0.25))
                .frame(minHeight: 260)
            
            Spacer()
        }
    }
}

@MainActor final class SnoozeViewModel: ObservableObject {
    struct Row: Identifiable {
        let alertKind: AlertKind
        let sectionTitle: String
        let statusText: String
        let statusTextColor: Color
        
        var id: Int { alertKind.rawValue }
        var isSnoozed: Bool
    }
    
    @Published private(set) var rows: [Row] = []
    @Published private(set) var snoozeAllSwitchIsOn = false
    @Published private(set) var bannerText = Texts_HomeView.snoozeAllDisabled
    @Published private(set) var bannerTextColor = Color(ConstantsAlerts.bannerTextColorWhenNotAllSnoozed)
    @Published private(set) var bannerBackgroundColor = Color(ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed)
    @Published private(set) var showAllSnoozedImage = false
    @Published var pickerData: SnoozePickerData?
    
    private let alertManager: AlertManager
    
    init(alertManager: AlertManager) {
        self.alertManager = alertManager
    }
    
    func refresh() {
        // This is the SwiftUI equivalent of configureSnoozeAllView() from
        // SnoozeViewController.swift, including the same banner text and reset rules.
        let snoozeStatus = alertManager.snoozeStatus()
        
        switch snoozeStatus {
        case .allSnoozed:
            if let snoozeAllAlertsUntilDate = UserDefaults.standard.snoozeAllAlertsUntilDate {
                // Keep the same simple 2-line banner as the previous UIKit screen:
                // line 1 confirms all alarms are snoozed, line 2 shows the remaining time.
                snoozeAllSwitchIsOn = true
                bannerText = Texts_HomeView.snoozeAllSnoozed
                    + "\n"
                    + snoozeAllAlertsUntilDate.daysAndHoursRemaining(appendRemaining: true)
                bannerTextColor = Color(.colorPrimary)
                bannerBackgroundColor = ConstantsUI.warningSectionBackgroundColor
            }
        case .urgent:
            UserDefaults.standard.snoozeAllAlertsFromDate = nil
            snoozeAllSwitchIsOn = false
            bannerText = Texts_HomeView.snoozeUrgentAlarms
            bannerTextColor = .red
            bannerBackgroundColor = Color(ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed)
        case .inactive, .notUrgent:
            UserDefaults.standard.snoozeAllAlertsFromDate = nil
            snoozeAllSwitchIsOn = false
            bannerText = Texts_HomeView.snoozeAllDisabled
            bannerTextColor = Color(ConstantsAlerts.bannerTextColorWhenNotAllSnoozed)
            bannerBackgroundColor = Color(ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed)
        }
        
        showAllSnoozedImage = snoozeStatus == .allSnoozed
        rows = showAllSnoozedImage ? [] : createRows()
    }
    
    func handleSnoozeAllToggleChanged(isOn: Bool) {
        if isOn {
            presentSnoozeAllPicker()
        } else {
            // User is turning Snooze All off, so clear both timestamps before refreshing.
            UserDefaults.standard.snoozeAllAlertsFromDate = nil
            UserDefaults.standard.snoozeAllAlertsUntilDate = nil
            refresh()
        }
    }
    
    func handleAlertToggleChanged(alertKind: AlertKind, isOn: Bool) {
        if isOn {
            pickerData = SnoozePickerData(
                alertManager.createPickerViewData(
                    forAlertKind: alertKind,
                    content: nil,
                    actionHandler: { self.refresh() },
                    cancelHandler: {
                        self.alertManager.unSnooze(alertKind: alertKind)
                        self.refresh()
                    }
                )
            )
        } else {
            // Changing from on to off means user wants to unsnooze.
            alertManager.unSnooze(alertKind: alertKind)
            refresh()
        }
    }
    
    private func createRows() -> [Row] {
        // This replaces the UITableView section/row building from
        // SnoozeViewController.cellForRowAt and titleForHeaderInSection.
        return alertManager.enabledAlertKinds().map { alertKind in
            let snoozeValue = alertManager.getSnoozeParameters(alertKind: alertKind).getSnoozeValue()
            
            return Row(
                alertKind: alertKind,
                sectionTitle: sectionTitle(for: alertKind),
                statusText: statusText(for: snoozeValue),
                statusTextColor: snoozeValue.isSnoozed ? Color(.colorPrimary) : Color(.colorTertiary),
                isSnoozed: snoozeValue.isSnoozed
            )
        }
    }
    
    private func presentSnoozeAllPicker() {
        // Reused from snoozeAllUISwitchAction(_:) in SnoozeViewController:
        // default to the closest configured Snooze All duration.
        let defaultSnoozeAllPeriodInMinutes = ConstantsAlerts.defaultSnoozeAllPeriodInMinutes
        let snoozeAllValueMinutes = ConstantsAlerts.snoozeAllValueMinutes
        var defaultRow = 0
        
        for (index, _) in snoozeAllValueMinutes.enumerated() {
            if snoozeAllValueMinutes[index] > defaultSnoozeAllPeriodInMinutes {
                break
            } else {
                defaultRow = index
            }
        }
        
        pickerData = SnoozePickerData(PickerViewData(
            withMainTitle: Texts_HomeView.snoozeAllTitle,
            withSubTitle: Texts_Alerts.selectSnoozeTime,
            withData: ConstantsAlerts.snoozeAllValueStrings,
            selectedRow: defaultRow,
            withPriority: .high,
            actionButtonText: Texts_Common.Ok,
            cancelButtonText: Texts_Common.Cancel,
            isFullScreen: true,
            onActionClick: { snoozeIndex in
                // Get snooze period and apply both timestamps, mirroring the
                // previous UIKit implementation.
                let snoozePeriod = snoozeAllValueMinutes[snoozeIndex]
                
                UserDefaults.standard.snoozeAllAlertsFromDate = Date()
                UserDefaults.standard.snoozeAllAlertsUntilDate = Date().addingTimeInterval(Double(snoozePeriod) * 60)
                self.refresh()
            },
            onCancelClick: {
                self.refresh()
            },
            didSelectRowHandler: nil
        ))
    }
    
    private func sectionTitle(for alertKind: AlertKind) -> String {
        return (alertKind.alertUrgencyType() == .urgent ? "\u{2757}" : "") + alertKind.alertTitle()
    }
    
    private func statusText(for snoozeValue: (isSnoozed: Bool, remainingSeconds: Int?)) -> String {
        guard snoozeValue.isSnoozed, let remainingSeconds = snoozeValue.remainingSeconds else {
            return TextsSnooze.not_snoozed
        }
        
        let snoozedTillDate = Date(timeIntervalSinceNow: Double(remainingSeconds))
        let showDate = snoozedTillDate.toMidnight() > Date()
        let formattedDate = showDate
            ? snoozedTillDate.formatted(date: .numeric, time: .shortened)
            : snoozedTillDate.formatted(date: .omitted, time: .shortened)
        
        return TextsSnooze.snoozed_until + " " + formattedDate
    }
}

/// Value wrapper used to present the existing alert picker data from SwiftUI.
struct SnoozePickerData: Identifiable {
    let id = UUID()
    let pickerViewData: PickerViewData

    init(_ pickerViewData: PickerViewData) {
        self.pickerViewData = pickerViewData
    }
}

/// Native replacement for PickerViewControllerModal when choosing a snooze duration.
struct SnoozePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRow: Int

    let pickerData: SnoozePickerData

    init(pickerData: SnoozePickerData) {
        self.pickerData = pickerData
        _selectedRow = State(initialValue: pickerData.pickerViewData.selectedRow)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if let subTitle = pickerData.pickerViewData.subTitle {
                    Text(subTitle)
                        .font(.headline)
                }

                Picker("", selection: $selectedRow) {
                    ForEach(pickerData.pickerViewData.data.indices, id: \.self) { index in
                        Text(pickerData.pickerViewData.data[index])
                            .tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: selectedRow) { selectedRow in
                    pickerData.pickerViewData.didSelectRowHandler?(selectedRow)
                }
            }
            .padding(.horizontal)
            .navigationTitle(pickerData.pickerViewData.mainTitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(pickerData.pickerViewData.cancelTitle ?? Texts_Common.Cancel) {
                        pickerData.pickerViewData.cancelHandler?()
                        finish()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(pickerData.pickerViewData.actionTitle ?? Texts_Common.Ok) {
                        pickerData.pickerViewData.actionHandler(selectedRow)
                        finish()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func finish() {
        UserDefaults.standard.updateSnoozeStatus.toggle()
        dismiss()
    }
}
