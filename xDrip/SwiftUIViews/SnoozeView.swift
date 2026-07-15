//
//  SnoozeView.swift
//  xdrip
//
//  Created by Paul Plant on 13/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Displays active alerts and controls individual or global snooze periods.
///
/// Alert state and snooze actions remain in `SnoozeViewModel`; this view owns only presentation and
/// dismissal of the picker used by configurable snooze periods.
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
                        .listRowBackground(row.isSnoozed ? ConstantsUI.warningSectionBackgroundColor : ConstantsAppColors.groupedBackground)
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

/// Builds active alert rows and applies snooze or unsnooze commands through `AlertManager`.
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
    @Published private(set) var bannerTextColor = ConstantsAlerts.bannerTextColorWhenNotAllSnoozed
    @Published private(set) var bannerBackgroundColor = ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed
    @Published private(set) var showAllSnoozedImage = false
    @Published var pickerData: SnoozePickerData?
    
    private let alertManager: AlertManager
    
    init(alertManager: AlertManager) {
        self.alertManager = alertManager
    }
    
    func refresh() {
        // Apply the shared snooze-all banner text and reset rules.
        let snoozeStatus = alertManager.snoozeStatus()
        
        switch snoozeStatus {
        case .allSnoozed:
            if let snoozeAllAlertsUntilDate = UserDefaults.standard.snoozeAllAlertsUntilDate {
                // Line 1 confirms all alarms are snoozed; line 2 shows the remaining time.
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
            bannerBackgroundColor = ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed
        case .inactive, .notUrgent:
            UserDefaults.standard.snoozeAllAlertsFromDate = nil
            snoozeAllSwitchIsOn = false
            bannerText = Texts_HomeView.snoozeAllDisabled
            bannerTextColor = ConstantsAlerts.bannerTextColorWhenNotAllSnoozed
            bannerBackgroundColor = ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed
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
        let snoozeValueMinutes = ConstantsAlerts.snoozeValueMinutes
        var defaultRow = 0
        
        for (index, _) in snoozeValueMinutes.enumerated() {
            if snoozeValueMinutes[index] > defaultSnoozeAllPeriodInMinutes {
                break
            } else {
                defaultRow = index
            }
        }
        
        pickerData = SnoozePickerData(PickerViewData(
            withMainTitle: Texts_HomeView.snoozeAllTitle,
            withSubTitle: Texts_Alerts.selectSnoozeTime,
            withData: ConstantsAlerts.snoozeValueStrings,
            selectedRow: defaultRow,
            withPriority: .high,
            actionButtonText: Texts_Alerts.snooze,
            cancelButtonText: Texts_Common.Cancel,
            isFullScreen: true,
            onActionClick: { snoozeIndex in
                // Get the snooze period and apply both timestamps.
                let snoozePeriod = snoozeValueMinutes[snoozeIndex]
                
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

/// Value model used to present the shared snooze-duration picker as a SwiftUI sheet.
struct SnoozePickerData: Identifiable {
    let id = UUID()
    let pickerViewData: PickerViewData

    init(_ pickerViewData: PickerViewData) {
        self.pickerViewData = pickerViewData
    }
}

/// Dark, compact layout used only by the modal snooze picker.
private struct SnoozePickerSheetLayout<Content: View>: View {
    let title: String?
    let subtitle: String?
    let accentColor: Color
    let cancelTitle: String
    let confirmationTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let content: Content

    init(
        title: String?,
        subtitle: String?,
        accentColor: Color,
        cancelTitle: String,
        confirmationTitle: String,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.cancelTitle = cancelTitle
        self.confirmationTitle = confirmationTitle
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.content = content()
    }

    var body: some View {
        ZStack {
            ConstantsAppColors.homePanelBackground
                .ignoresSafeArea()

            VStack(spacing: 4) {
                HStack(spacing: 14) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        if let title, !title.isEmpty {
                            Text(title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(ConstantsAppColors.primaryText)
                        }

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.body)
                                .foregroundStyle(ConstantsAppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 0) {
                    Button(cancelTitle, action: onCancel)
                        .font(.title3.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .tint(ConstantsAppColors.urgent)
                        .foregroundStyle(.white)

                    Spacer(minLength: 24)

                    Button(confirmationTitle, action: onConfirm)
                        .font(.title3.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .tint(ConstantsAppColors.normal)
                        .foregroundStyle(.white)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .colorScheme(.dark)
        .presentationDragIndicator(.visible)
    }
}

/// Native wheel picker for one alert snooze duration.
struct SnoozePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRow: Int

    let pickerData: SnoozePickerData

    init(pickerData: SnoozePickerData) {
        self.pickerData = pickerData
        _selectedRow = State(initialValue: pickerData.pickerViewData.selectedRow)
    }

    var body: some View {
        SnoozePickerSheetLayout(
            title: pickerData.pickerViewData.mainTitle,
            subtitle: pickerData.pickerViewData.subTitle,
            accentColor: pickerData.pickerViewData.priority == .high ? ConstantsAppColors.urgent : ConstantsAppColors.accent,
            cancelTitle: pickerData.pickerViewData.cancelTitle ?? Texts_Common.Cancel,
            confirmationTitle: pickerData.pickerViewData.actionTitle ?? Texts_Alerts.snooze,
            onCancel: cancel,
            onConfirm: confirm
        ) {
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
        .presentationDetents([.height(390)])
        .interactiveDismissDisabled()
    }

    private func cancel() {
        pickerData.pickerViewData.cancelHandler?()
        finish()
    }

    private func confirm() {
        pickerData.pickerViewData.actionHandler(selectedRow)
        finish()
    }

    private func finish() {
        UserDefaults.standard.updateSnoozeStatus.toggle()
        dismiss()
    }
}
