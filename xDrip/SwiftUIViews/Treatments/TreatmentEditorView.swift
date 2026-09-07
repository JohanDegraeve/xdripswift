//
//  TreatmentEditorView.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

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
                            TextField(viewModel.valuePlaceholder, text: $viewModel.enteredValue)
                                .keyboardType(viewModel.selectedType == .BasalInjection ? .numberPad : .decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color(.colorSecondary))
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
