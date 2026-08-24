//
//  SnoozeView.swift
//  xdrip
//
//  Created by Paul Plant on 13/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

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
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OnlineHelpButton(topic: .snooze)
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                viewModel.refresh()
            }
        }
        .colorScheme(.dark)
        .overlay {
            // Keep the Snooze screen visually behind its duration picker.
            if viewModel.pickerData != nil {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $viewModel.pickerData) { pickerData in
            // Pickers opened from the Snooze screen use the normal in-app presentation.
            StandardSnoozePickerView(pickerData: pickerData)
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
                .tint(ConstantsAppColors.toolbarDestructiveAction)
                .foregroundStyle(Color(.colorPrimary))
                
                snoozeAllStatusRow()
                    .listRowBackground(snoozeAllStatusBackgroundColor())
            }
            
            if !viewModel.showAllSnoozedImage {
                ForEach(viewModel.rows) { row in
                    Section(header: alarmSectionHeader(title: row.sectionTitle)) {
                        alarmRow(for: row)
                            .listRowBackground(row.isSnoozed ? ConstantsUI.warningSectionBackgroundColor : Color(.secondarySystemGroupedBackground))
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
    
    @ViewBuilder private func alarmRow(for row: SnoozeViewModel.Row) -> some View {
        // Keep the row content focused on current snooze state. The alarm name stays
        // in the section header so the grouped layout matches the other SwiftUI screens.
        Toggle(isOn: Binding(
            get: { row.isSnoozed },
            set: { isOn in
                viewModel.handleAlertToggleChanged(alertKind: row.alertKind, isOn: isOn)
            }
        )) {
            Text(row.statusText)
                .foregroundStyle(row.statusTextColor)
                .padding(.vertical, 6)
        }
        .tint(.green)
    }
    
    @ViewBuilder private func alarmSectionHeader(title: String) -> some View {
        Text(title)
            .textCase(nil)
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

/// Visual scale and action treatment for normal selection and alert handling.
private enum SnoozePickerPresentation {
    case standard
    case standardAlert
    case largeAlert

    var isAlert: Bool {
        self != .standard
    }

    var isLarge: Bool {
        self == .largeAlert
    }

    var iconSize: CGFloat {
        isLarge ? 42 : 28
    }

    var iconWidth: CGFloat {
        isLarge ? 54 : 40
    }

    var titleFont: Font {
        isLarge ? .system(size: 40, weight: .bold) : .title2.weight(.bold)
    }

    var subtitleFont: Font {
        isLarge ? .title2.weight(.semibold) : .body
    }

    var detents: Set<PresentationDetent> {
        // The alert picker needs more room than the standard sheet without obscuring the whole app.
        isLarge ? [.fraction(0.7)] : [.height(390)]
    }
}

/// Shared dark shell that keeps both picker variants structurally identical.
private struct SnoozePickerSheetLayout<Content: View>: View {
    let presentation: SnoozePickerPresentation
    let title: String?
    let subtitle: String?
    let accentColor: Color
    let cancelTitle: String
    let confirmationTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let content: Content

    init(
        presentation: SnoozePickerPresentation,
        title: String?,
        subtitle: String?,
        accentColor: Color,
        cancelTitle: String,
        confirmationTitle: String,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.presentation = presentation
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
                        .font(.system(size: presentation.iconSize, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: presentation.iconWidth)

                    VStack(alignment: .leading, spacing: presentation.isLarge ? 6 : 3) {
                        if let title, !title.isEmpty {
                            Text(title)
                                .font(presentation.titleFont)
                                .foregroundStyle(ConstantsAppColors.primaryText)
                                .minimumScaleFactor(0.75)
                        }

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(presentation.subtitleFont)
                                .foregroundStyle(ConstantsAppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .colorScheme(.dark)
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var actionButtons: some View {
        HStack(spacing: 0) {
            if presentation.isAlert {
                // Alert actions retain their red/green meaning at the selected presentation scale.
                Button(action: onCancel) {
                    alertButtonLabel(cancelTitle)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(ConstantsAppColors.urgent)
                    .foregroundStyle(.white)

                Spacer(minLength: 24)

                Button(action: onConfirm) {
                    alertButtonLabel(confirmationTitle)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(ConstantsAppColors.normal)
                    .foregroundStyle(.white)
            } else {
                // In-app snoozing uses normal-sized buttons while preserving the same bottom layout.
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(ConstantsAppColors.toolbarNeutralAction)

                Spacer(minLength: 24)

                Button(action: onConfirm) {
                    Text(confirmationTitle)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        // The large variant remains prominent through its typography and colors without oversized controls.
        .controlSize(.regular)
    }

    private func alertButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(presentation.isLarge ? .title2.weight(.bold) : .body.weight(.semibold))
            // Increase only the large alert's visible button and tap target without fixed sizing.
            .padding(.horizontal, presentation.isLarge ? 10 : 0)
            .padding(.vertical, presentation.isLarge ? 6 : 0)
    }
}

/// UIKit-backed wheel used only where larger row heights are required for alarm handling.
private struct LargeSnoozeWheelPicker: UIViewRepresentable {
    let data: [String]
    @Binding var selectedRow: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let pickerView = UIPickerView()
        pickerView.backgroundColor = .clear
        pickerView.dataSource = context.coordinator
        pickerView.delegate = context.coordinator
        pickerView.selectRow(selectedRow, inComponent: 0, animated: false)
        return pickerView
    }

    func updateUIView(_ pickerView: UIPickerView, context: Context) {
        context.coordinator.parent = self
        pickerView.reloadAllComponents()

        if pickerView.selectedRow(inComponent: 0) != selectedRow {
            pickerView.selectRow(selectedRow, inComponent: 0, animated: false)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: LargeSnoozeWheelPicker

        init(_ parent: LargeSnoozeWheelPicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            1
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            parent.data.count
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            56
        }

        func pickerView(
            _ pickerView: UIPickerView,
            viewForRow row: Int,
            forComponent component: Int,
            reusing view: UIView?
        ) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.backgroundColor = .clear
            label.adjustsFontForContentSizeCategory = true
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
            label.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
                for: UIFont.systemFont(ofSize: 36, weight: .bold),
                maximumPointSize: 42
            )
            label.text = parent.data[row]
            label.textAlignment = .center
            label.textColor = .label
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            parent.selectedRow = row
        }
    }
}

/// Shared snooze selection and callback handling with presentation-specific content.
private struct SnoozePickerPresentationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRow: Int
    @State private var actionWasHandled = false

    let pickerData: SnoozePickerData
    let presentation: SnoozePickerPresentation

    init(pickerData: SnoozePickerData, presentation: SnoozePickerPresentation) {
        self.pickerData = pickerData
        self.presentation = presentation
        _selectedRow = State(initialValue: pickerData.pickerViewData.selectedRow)
    }

    var body: some View {
        SnoozePickerSheetLayout(
            presentation: presentation,
            // Both normal-scale variants keep the standard title hierarchy and neutral icon.
            title: presentation.isLarge
                ? pickerData.pickerViewData.largePresentationTitle ?? pickerData.pickerViewData.mainTitle
                : pickerData.pickerViewData.subTitle,
            subtitle: presentation.isLarge
                ? nil
                : pickerData.pickerViewData.mainTitle,
            accentColor: presentation.isLarge
                ? pickerData.pickerViewData.priority == .high
                    ? ConstantsAppColors.urgent
                    : ConstantsAppColors.accent
                : Color(.colorSecondary),
            cancelTitle: pickerData.pickerViewData.cancelTitle ?? Texts_Common.Cancel,
            confirmationTitle: presentation.isAlert
                ? pickerData.pickerViewData.actionTitle ?? Texts_Alerts.snooze
                : Texts_Common.Ok,
            onCancel: cancel,
            onConfirm: confirm
        ) {
            picker
        }
        .presentationDetents(presentation.detents)
        .interactiveDismissDisabled(presentation.isLarge)
        .onDisappear(perform: handleInteractiveDismissal)
    }

    @ViewBuilder private var picker: some View {
        if presentation.isLarge {
            // SwiftUI's wheel has a fixed row height, so the alarm variant uses native oversized rows.
            LargeSnoozeWheelPicker(
                data: pickerData.pickerViewData.data,
                selectedRow: $selectedRow
            )
            .frame(maxWidth: .infinity, minHeight: 250)
            .onChange(of: selectedRow, perform: selectionChanged)
        } else {
            Picker("", selection: $selectedRow) {
                ForEach(pickerData.pickerViewData.data.indices, id: \.self) { index in
                    Text(pickerData.pickerViewData.data[index])
                        .tag(index)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: selectedRow, perform: selectionChanged)
        }
    }

    private func selectionChanged(_ selectedRow: Int) {
        pickerData.pickerViewData.didSelectRowHandler?(selectedRow)
    }

    private func cancel() {
        actionWasHandled = true
        pickerData.pickerViewData.cancelHandler?()
        finish()
    }

    private func confirm() {
        actionWasHandled = true
        pickerData.pickerViewData.actionHandler(selectedRow)
        finish()
    }

    private func handleInteractiveDismissal() {
        // Both normal-scale pickers are swipeable and treat dismissal exactly like Cancel.
        guard !presentation.isLarge, !actionWasHandled else { return }

        actionWasHandled = true
        pickerData.pickerViewData.cancelHandler?()
        UserDefaults.standard.updateSnoozeStatus.toggle()
    }

    private func finish() {
        UserDefaults.standard.updateSnoozeStatus.toggle()
        dismiss()
    }
}

/// Normal-scale snooze picker used by controls inside the app.
struct StandardSnoozePickerView: View {
    let pickerData: SnoozePickerData

    var body: some View {
        SnoozePickerPresentationView(pickerData: pickerData, presentation: .standard)
    }
}

/// Standard picker layout with the same red/green actions as the oversized alert view.
struct StandardAlertSnoozePickerView: View {
    let pickerData: SnoozePickerData

    var body: some View {
        SnoozePickerPresentationView(pickerData: pickerData, presentation: .standardAlert)
    }
}

/// Oversized snooze picker used when an alert demands immediate attention.
struct LargeSnoozePickerView: View {
    let pickerData: SnoozePickerData

    var body: some View {
        SnoozePickerPresentationView(pickerData: pickerData, presentation: .largeAlert)
    }
}
