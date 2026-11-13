//
//  TreatmentEditorView.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

/// Presents treatment type selection for new entries, or opens an existing entry directly.
struct TreatmentEditorContainerView: View {
    let coreDataManager: CoreDataManager
    let editorState: TreatmentEditorState
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            switch editorState {
            case .add:
                List {
                    Section(Texts_TreatmentsView.treatmentType) {
                        ForEach(TreatmentEditorViewModel.supportedTreatmentTypes, id: \.rawValue) { treatmentType in
                            NavigationLink {
                                TreatmentEditorScreen(
                                    coreDataManager: coreDataManager,
                                    treatmentToEdit: nil,
                                    initialType: treatmentType,
                                    onSave: onSave
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    treatmentType.iconView()
                                        .frame(width: 24)
                                        .accessibilityHidden(true)
                                    Text(treatmentType.asString())
                                        .foregroundStyle(ConstantsAppColors.rowTitleText)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .ipadReadableContentWidth(720)
                .navigationTitle(Texts_TreatmentsView.addTreatmentTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(Texts_Common.Cancel, action: onCancel)
                            .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                    }
                }
            case .edit(let treatment):
                // A stale or deleted row must not open an empty editor in add mode.
                if let entry = TreatmentEntryAccessor(coreDataManager: coreDataManager)
                    .getTreatment(objectID: treatment.objectID), !entry.isDeleted, !entry.treatmentdeleted {
                    TreatmentEditorScreen(
                        coreDataManager: coreDataManager,
                        treatmentToEdit: entry,
                        onSave: onSave,
                        onCancel: onCancel
                    )
                } else {
                    Text(Texts_TreatmentsView.noTreatmentsToShow)
                        .navigationTitle(Texts_TreatmentsView.editTreatmentTitle)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(Texts_Common.Cancel, action: onCancel)
                            }
                        }
                }
            }
        }
        .colorScheme(.dark)
    }
}

/// Owns a separate draft for each entry form, so choosing another type starts fresh.
private struct TreatmentEditorScreen: View {
    @StateObject private var viewModel: TreatmentEditorViewModel

    let onSave: () -> Void
    let onCancel: (() -> Void)?

    init(
        coreDataManager: CoreDataManager,
        treatmentToEdit: TreatmentEntry?,
        initialType: TreatmentType = .Carbs,
        onSave: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: TreatmentEditorViewModel(
            coreDataManager: coreDataManager,
            treatmentToEdit: treatmentToEdit,
            initialType: initialType
        ))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        TreatmentEditorView(
            viewModel: viewModel,
            onDelete: {
                if viewModel.deleteTreatment() {
                    onSave()
                }
            }
        )
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onCancel = onCancel {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: onCancel)
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(Texts_TreatmentsView.saveTreatment) {
                    if viewModel.saveTreatment() {
                        onSave()
                    }
                }
                .tint(ConstantsAppColors.toolbarAction)
                .disabled(!viewModel.canSaveTreatment)
            }
        }
    }
}

/// Native form used to add or edit a treatment.
struct TreatmentEditorView: View {
    // MARK: - private properties

    @ObservedObject var viewModel: TreatmentEditorViewModel

    let onDelete: (() -> Void)?

    // MARK: - SwiftUI views

    var body: some View {
        Form {
            Section(footer: editorFooterView()) {
                HStack {
                    Text(Texts_TreatmentsView.type)
                    Spacer()
                    HStack(spacing: 8) {
                        viewModel.selectedType.iconView()
                            .accessibilityHidden(true)
                        Text(viewModel.selectedType.asString())
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                DatePicker(selection: $viewModel.selectedDate, in: ...viewModel.latestSelectableDate, displayedComponents: [.date, .hourAndMinute]) {
                    Text(Texts_BgReadings.date)
                        .foregroundStyle(Color(.colorPrimary))
                }
                .foregroundStyle(Color(.colorSecondary))

                if viewModel.showsNumericValueEditor {
                    LabeledContent(Texts_TreatmentsView.value) {
                        HStack(spacing: 6) {
                            Group {
                                if viewModel.selectedType == .BasalInjection {
                                    BasalDoseTextField(placeholder: viewModel.valuePlaceholder, text: $viewModel.enteredValue)
                                } else {
                                    TextField(viewModel.valuePlaceholder, text: $viewModel.enteredValue)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(Color(.colorSecondary))
                                }
                            }
                            .frame(minWidth: 72, maxWidth: 96, alignment: .trailing)

                            Text(viewModel.unitText)
                                .foregroundStyle(Color(.colorTertiary))
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }

                if viewModel.selectedType == .BasalInjection {
                    LabeledContent(Texts_TreatmentsView.insulinDescription) {
                        TextField(Texts_TreatmentsView.insulinDescriptionPlaceholder, text: $viewModel.enteredInsulinDescription)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                if viewModel.showsNotesEditor {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Texts_TreatmentsView.notes)
                        TextEditor(text: $viewModel.enteredNotesValue)
                            .frame(minHeight: 120)
                            .padding(6)
                            .background(ConstantsAppColors.groupedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color(.colorSecondary))
                            .overlay(alignment: .topLeading) {
                                if viewModel.enteredNotesValue.isEmpty {
                                    Text(Texts_TreatmentsView.notePlaceholder)
                                        .foregroundStyle(Color(.placeholderText))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 14)
                                }
                            }
                    }
                }
            }

            Section {
                LabeledContent(Texts_TreatmentsView.enteredBy) {
                    TextField(Texts_Common.unknown, text: $viewModel.enteredByValue)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color(.colorSecondary))
                        .frame(minWidth: 120, maxWidth: 220, alignment: .trailing)
                }
            }

            if let onDelete = onDelete, !viewModel.isAddMode {
                Section {
                    Button(role: .destructive, action: onDelete) {
                        Text(Texts_TreatmentsView.deleteTreatment)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .colorScheme(.dark)
        .ipadReadableContentWidth(720)
        .alert(item: $viewModel.alertMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text(Texts_Common.Ok))
            )
        }
        .onAppear {
            viewModel.validateSelectedDateIfNeeded()
        }
        .onChange(of: viewModel.selectedType) { _ in
            viewModel.validateSelectedDateIfNeeded()
        }
        .onChange(of: viewModel.selectedDate) { _ in
            viewModel.validateSelectedDateIfNeeded()
        }
    }

    @ViewBuilder private func editorFooterView() -> some View {
        if viewModel.selectedType == .BasalInjection, viewModel.didPrefillBasalInjection {
            Text(Texts_TreatmentsView.basalInjectionCopiedFooter)
        }

        if let helperText = viewModel.helperText {
            Text(helperText)
                .foregroundStyle(Color(.systemRed))
        }
    }
}

/// Block a second decimal place before it appears in the field (issue #783).
/// A SwiftUI binding updates too late and makes the rejected digit look like an autocorrection.
struct BasalDoseTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.accessibilityLabel = Texts_TreatmentsView.value
        field.text = text
        field.keyboardType = .decimalPad
        field.textAlignment = .right
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor(named: "colorSecondary")
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text {
            field.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let replacementRange = Range(range, in: current) else { return false }
            let proposed = current.replacingCharacters(in: replacementRange, with: string)
            let parts = proposed.split(omittingEmptySubsequences: false) { $0 == "." || $0 == "," }
            // Allow an empty field and a trailing separator while editing. A rejected edit or
            // paste must leave the existing dose unchanged, rather than rounding or truncating it.
            guard proposed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }),
                  parts.count <= 2,
                  parts.count == 1 || parts[1].count <= 1 else { return false }
            if proposed.isEmpty || proposed == "." || proposed == "," { return true }
            guard let units = proposed.toDouble() else { return false }
            // Zero is useful while replacing a dose. Save still requires a positive half-unit step.
            return units >= 0 && units <= TreatmentEditorViewModel.maximumBasalInjectionUnits
        }

        @objc func textDidChange(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }
    }
}
