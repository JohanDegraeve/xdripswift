//
//  BluetoothPeripheralDetailView.swift
//  xdrip
//
//  Created by Paul Plant on 19/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct BluetoothPeripheralDetailView: View {
    @ObservedObject var state: BluetoothPeripheralDetailState

    var body: some View {
        List {
            Section {
                Button(action: state.connectButtonTapped) {
                    HStack {
                        Text(state.connectButtonTitle)
                            .font(.headline)

                        Spacer()

                        Image(systemName: state.category.systemImage(for: state.connectionStatus))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(state.connectionStatus.tintColor)
                    }
                    .foregroundStyle(state.connectButtonIsEnabled ? ConstantsUI.plusButtonColor : Color.gray)
                }
                .disabled(!state.connectButtonIsEnabled)
            }

            ForEach(state.sections) { section in
                Section(section.title ?? "") {
                    ForEach(section.rows) { row in
                        BluetoothPeripheralDetailRowView(row: row)
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
            if state.canDeletePeripheral {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: state.deleteButtonTapped) {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .alert(item: $state.pendingAlert, content: makeAlert)
        .onAppear(perform: state.start)
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
            return Color(.colorSecondary)
        case .scanning, .connected:
            return .green
        }
    }
}

struct BluetoothPeripheralTextEntryView: View {
    let textEntry: BluetoothPeripheralTextEntry
    let close: () -> Void

    @State private var text: String
    @State private var validationMessage: String?

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
                    .textInputAutocapitalization(.characters)
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
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(textEntry.actionTitle, action: submit)
                    .disabled(!actionIsEnabled)
            }
        }
        .colorScheme(.dark)
    }

    private var actionIsEnabled: Bool {
        textEntry.actionIsEnabled?(text) ?? true
    }

    private func submit() {
        guard actionIsEnabled else { return }

        if let validationMessage = textEntry.inputValidator?(text) {
            self.validationMessage = validationMessage
            return
        }

        textEntry.actionHandler(text)
        close()
    }
}

struct BluetoothPeripheralSelectionListView: View {
    let selectionList: BluetoothPeripheralSelectionList
    let close: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(Array(selectionList.data.enumerated()), id: \.offset) { index, title in
                    Button {
                        select(index: index)
                    } label: {
                        HStack {
                            Text(title)
                                .foregroundStyle(Color(.colorPrimary))

                            Spacer()

                            if index == selectionList.selectedRow {
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
            }
        }
        .colorScheme(.dark)
    }

    private func select(index: Int) {
        selectionList.actionHandler(index)
        close()
    }
}

private struct BluetoothPeripheralDetailRowView: View {
    let row: BluetoothPeripheralDetailRow

    var body: some View {
        if let toggle = row.toggle {
            Toggle(isOn: Binding(get: {
                toggle.isOn
            }, set: toggle.setValue)) {
                Text(row.title)
                    .foregroundStyle(row.isEnabled ? Color(.colorPrimary) : Color.gray)
            }
            .disabled(!row.isEnabled)
        } else if let action = row.action, row.isEnabled {
            Button(action: action) {
                BluetoothPeripheralSettingsRow(
                    title: row.title,
                    detail: row.detail,
                    showsDisclosure: row.showsDisclosure,
                    isEnabled: row.isEnabled
                )
            }
            .buttonStyle(.plain)
        } else {
            BluetoothPeripheralSettingsRow(
                title: row.title,
                detail: row.detail,
                showsDisclosure: false,
                isEnabled: row.isEnabled
            )
        }
    }
}
