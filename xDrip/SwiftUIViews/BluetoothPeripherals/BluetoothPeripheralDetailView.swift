//
//  BluetoothPeripheralDetailView.swift
//  xdrip
//
//  Created by Paul Plant on 19/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Native detail screen for an existing or newly configured Bluetooth peripheral.
struct BluetoothPeripheralDetailView: View {
    @ObservedObject var state: BluetoothPeripheralDetailState

    var body: some View {
        List {
            Section {
                BluetoothPeripheralStatusBannerView(state: state)
                    .listRowInsets(ConstantsUI.bluetoothPeripheralStatusBannerRowInsets)
                    .listRowBackground(state.connectionStatus.rowBackgroundColor)

                Button(action: state.connectButtonTapped) {
                    Text(state.connectButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(connectButtonTint)
                .disabled(!state.connectButtonIsEnabled)
                .listRowInsets(ConstantsUI.bluetoothPeripheralStatusButtonRowInsets)
                .listRowBackground(state.connectionStatus.rowBackgroundColor)
            } header: {
                Text(Texts_BluetoothPeripheralView.status)
                    .foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
            } footer: {
                if let statusFooterText = state.statusFooterText {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let statusFooterSystemImage = state.statusFooterSystemImage {
                            Image(systemName: statusFooterSystemImage)
                                .foregroundStyle(state.statusFooterSymbolColor)
                        }

                        Text(statusFooterText)
                    }
                        .foregroundStyle(state.statusFooterIsWarning ? Color(.systemRed) : ConstantsUI.listSectionFooterTextColor)
                        .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
                }
            }

            ForEach(state.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        BluetoothPeripheralDetailRowView(row: row)
                    }
                } header: {
                    BluetoothPeripheralDetailSectionHeaderView(section: section)
                } footer: {
                    if !section.footerLines.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(section.footerLines) { footerLine in
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Image(systemName: footerLine.systemImage)
                                        .foregroundStyle(footerLine.symbolColor)
                                    Text(footerLine.text)
                                }
                                .foregroundStyle(footerLine.isActive ? ConstantsUI.listSectionFooterTextColor : Color(.colorTertiary))
                            }
                        }
                        .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
                    } else if let footer = section.footer {
                        Text(footer)
                            .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                            .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(state.screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                OnlineHelpButton(topic: state.onlineHelpTopic)

                if state.canDeletePeripheral {
                    Button(action: state.deleteButtonTapped) {
                        Image(systemName: "trash")
                    }
                    .tint(ConstantsAppColors.toolbarDestructiveAction)
                }
            }
        }
        .alert(item: $state.pendingAlert, content: makeAlert)
        .onAppear(perform: state.start)
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 780 : .infinity)
        .frame(maxWidth: .infinity)
    }

    private var connectButtonTint: Color {
        state.connectButtonTintColor.color
    }

    private func makeAlert(_ alert: BluetoothPeripheralDetailAlert) -> Alert {
        if let primaryAction = alert.primaryAction {
            let primaryTitle = alert.primaryButtonTitle ?? Texts_Common.Ok

            if let secondaryTitle = alert.secondaryButtonTitle {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(primaryTitle)) {
                        primaryAction()
                        state.pendingAlert = nil
                    },
                    secondaryButton: .cancel(Text(secondaryTitle)) {
                        alert.secondaryAction?()
                        state.pendingAlert = nil
                    }
                )
            }

            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(primaryTitle)) {
                    primaryAction()
                    state.pendingAlert = nil
                }
            )
        }

        return Alert(
            title: Text(alert.title),
            message: Text(alert.message),
            dismissButton: .default(Text(Texts_Common.Ok)) {
                alert.secondaryAction?()
                state.pendingAlert = nil
            }
        )
    }
}

private extension BluetoothPeripheralDisplayStatus {
    var tintColor: Color {
        switch self {
        case .notScanning:
            return Color(.colorTertiary)
        case .discovering, .connecting, .reconnecting:
            return Color(.systemYellow)
        case .waitingForNextReading, .connected:
            return .green
        }
    }

    var rowBackgroundColor: Color {
        switch self {
        case .notScanning:
            return Color(.secondarySystemGroupedBackground)
        case .discovering, .connecting, .reconnecting:
            return ConstantsUI.connectingRowBackgroundColor
        case .waitingForNextReading, .connected:
            return ConstantsUI.activeRowBackgroundColor
        }
    }

    var antennaSystemImage: String {
        switch self {
        case .notScanning:
            return "antenna.radiowaves.left.and.right.slash"
        case .discovering, .connecting, .reconnecting, .waitingForNextReading, .connected:
            return "antenna.radiowaves.left.and.right"
        }
    }
}

private extension BluetoothPeripheralConnectButtonTintColor {
    var color: Color {
        switch self {
        case .disabledGray:
            return Color(.systemGray)
        case .neutral:
            return Color(.systemGray2)
        case .green:
            return .green
        case .blue:
            return .blue
        case .red:
            return .red
        }
    }
}

/// Current scan or connection state shown above the detail sections.
private struct BluetoothPeripheralStatusBannerView: View {
    @ObservedObject var state: BluetoothPeripheralDetailState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: state.connectionStatus.antennaSystemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(state.connectionStatus.tintColor)
                .frame(width: 24)

            Text(state.connectionStatus.fullStatusText)
                .foregroundStyle(Color(.colorPrimary))

            Spacer()

            if let connectionWaitStartedAt = state.connectionWaitStartedAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .accessibilityHidden(true)

                    Text(connectionWaitStartedAt, style: .timer)
                        .monospacedDigit()
                }
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
        .padding(.vertical, 3)
    }
}

/// Section title and optional transmitter status indicator.
private struct BluetoothPeripheralDetailSectionHeaderView: View {
    let section: BluetoothPeripheralDetailSection

    var body: some View {
        if section.title != nil || section.headerDetail != nil || section.headerSymbol != nil {
            HStack {
                if let title = section.title {
                    Text(title)
                        .foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
                }

                Spacer()

                HStack(spacing: 4) {
                    if let headerDetail = section.headerDetail {
                        Text(headerDetail)
                            .foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
                    }

                    if let headerSymbol = section.headerSymbol {
                        Image(systemName: headerSymbol.systemName)
                            .foregroundStyle(headerSymbol.color)
                            .imageScale(.medium)
                    }
                }
            }
        }
    }
}

/// Native text-entry destination requested by a peripheral detail row.
struct BluetoothPeripheralTextEntryView: View {
    let textEntry: BluetoothPeripheralTextEntry
    let close: () -> Void

    @State private var text: String
    @State private var validationMessage: String?
    @State private var hasSubmitted = false

    init(textEntry: BluetoothPeripheralTextEntry, close: @escaping () -> Void) {
        self.textEntry = textEntry
        self.close = close
        _text = State(initialValue: textEntry.text ?? "")
    }

    var body: some View {
        Form {
            if let message = textEntry.message {
                Section {
                    Text(message)
                        .foregroundStyle(Color(.colorSecondary))
                }
            }

            Section {
                TextField(textEntry.placeholder ?? "", text: $text)
                    .keyboardType(textEntry.keyboardType)
                    .textInputAutocapitalization(textEntry.textInputAutocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(submit)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(Color.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(textEntry.title ?? "")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(textEntry.cancelTitle, action: close)
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(textEntry.actionTitle, action: submit)
                    .tint(ConstantsAppColors.toolbarAction)
                    .disabled(!actionIsEnabled || hasSubmitted)
            }
        }
        .colorScheme(.dark)
    }

    private var actionIsEnabled: Bool {
        textEntry.actionIsEnabled?(text) ?? true
    }

    private func submit() {
        guard actionIsEnabled, !hasSubmitted else { return }

        if let validationMessage = textEntry.inputValidator?(text) {
            self.validationMessage = validationMessage
            return
        }

        // Ignore another tap while the next screen is opening.
        hasSubmitted = true
        textEntry.actionHandler(text)
        if textEntry.dismissAfterSubmit {
            close()
        }
    }
}

/// Native selection destination requested by a peripheral detail row.
struct BluetoothPeripheralSelectionListView: View {
    @State private var selectedRow: Int

    let selectionList: BluetoothPeripheralSelectionList
    let close: () -> Void
    private let initialSelectedRow: Int

    init(selectionList: BluetoothPeripheralSelectionList, close: @escaping () -> Void) {
        self.selectionList = selectionList
        self.close = close
        let initialSelectedRow = selectionList.selectedRow ?? 0
        self.initialSelectedRow = initialSelectedRow
        _selectedRow = State(initialValue: initialSelectedRow)
    }

    var body: some View {
        List {
            if let explanation = selectionList.explanation {
                Section {
                    Text(explanation)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            Section {
                ForEach(Array(selectionList.data.enumerated()), id: \.offset) { index, title in
                    Button {
                        select(index: index)
                    } label: {
                        HStack {
                            optionTitle(title)
                                .foregroundStyle(Color(.colorPrimary))

                            Spacer()

                            if index == selectedRow {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(ConstantsUI.plusButtonColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(selectionList.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Texts_Common.Cancel, action: close)
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(Texts_Common.Ok, action: confirmSelection)
                    .tint(ConstantsAppColors.toolbarAction)
                    .disabled(selectedRow == initialSelectedRow)
            }
        }
        .colorScheme(.dark)
    }

    private func select(index: Int) {
        selectedRow = index
    }

    @ViewBuilder
    private func optionTitle(_ title: String) -> some View {
        if selectionList.emphasizesParenthesizedSuffix,
           let suffixRange = parenthesizedSuffixRange(in: title) {
            Text(String(title[..<suffixRange.lowerBound]))
                + Text(String(title[suffixRange])).bold()
        } else {
            Text(title)
        }
    }

    private func parenthesizedSuffixRange(in title: String) -> Range<String.Index>? {
        if title.hasSuffix(")"), let range = title.range(of: " (", options: .backwards) {
            return title.index(after: range.lowerBound)..<title.endIndex
        }
        if title.hasSuffix("）"), let range = title.range(of: "（", options: .backwards) {
            return range.lowerBound..<title.endIndex
        }
        return nil
    }

    private func confirmSelection() {
        guard selectedRow != initialSelectedRow else { return }
        selectionList.actionHandler(selectedRow)
        close()
    }
}

/// Renders the action, toggle, text, selection or information represented by one row model.
private struct BluetoothPeripheralDetailRowView: View {
    let row: BluetoothPeripheralDetailRow

    var body: some View {
        if let toggle = row.toggle {
            HStack(spacing: 12) {
                Text(row.title)
                    .foregroundStyle(row.isEnabled ? Color(.colorPrimary) : Color.gray)

                Spacer(minLength: 12)

                if let detailSymbol = row.detailSymbol {
                    Image(systemName: detailSymbol.systemName)
                        .foregroundStyle(row.isEnabled ? detailSymbol.color : .gray)
                        .imageScale(.medium)
                }

                Toggle("", isOn: Binding(get: {
                    toggle.isOn
                }, set: toggle.setValue))
                .labelsHidden()
            }
            .disabled(!row.isEnabled)
        } else if let action = row.action, row.isEnabled {
            Button(action: action) {
                BluetoothPeripheralSettingsRow(
                    title: row.title,
                    detail: row.detail,
                    detailIndicator: row.detailIndicator,
                    detailSymbol: row.detailSymbol,
                    detailLineLimit: row.detailLineLimit,
                    showsDisclosure: row.showsDisclosure,
                    isEnabled: row.isEnabled
                )
            }
            .buttonStyle(.plain)
        } else {
            BluetoothPeripheralSettingsRow(
                title: row.title,
                detail: row.detail,
                detailIndicator: row.detailIndicator,
                detailSymbol: row.detailSymbol,
                detailLineLimit: row.detailLineLimit,
                showsDisclosure: false,
                isEnabled: row.isEnabled
            )
        }
    }
}
