//
//  TreatmentEditorView.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

struct TreatmentEditorContainerView: View {
    // MARK: - private properties

    let onSave: () -> Void
    let onCancel: () -> Void

    @StateObject private var viewModel: TreatmentEditorViewModel

    // MARK: - initialization

    init(
        coreDataManager: CoreDataManager,
        editorState: TreatmentEditorState,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel

        switch editorState {
        case .add:
            _viewModel = StateObject(
                wrappedValue: TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: nil)
            )
        case .edit(let treatment):
            let treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
            let treatmentEntry = treatmentEntryAccessor.getTreatment(objectID: treatment.objectID)
            _viewModel = StateObject(
                wrappedValue: TreatmentEditorViewModel(
                    coreDataManager: coreDataManager,
                    treatmentToEdit: treatmentEntry
                )
            )
        }
    }

    // MARK: - SwiftUI views

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_TreatmentsView.saveTreatment) {
                        if viewModel.saveTreatment() {
                            onSave()
                        }
                    }
                }
            }
        }
        .colorScheme(.dark)
    }
}

struct TreatmentEditorView: View {
    // MARK: - private properties

    @ObservedObject var viewModel: TreatmentEditorViewModel

    let onDelete: (() -> Void)?

    // MARK: - SwiftUI views

    var body: some View {
        List {
            Section(footer: editorFooterView()) {
                if viewModel.isAddMode {
                    Picker(Texts_TreatmentsView.type, selection: $viewModel.selectedType) {
                        ForEach(TreatmentEditorViewModel.supportedTreatmentTypes, id: \.rawValue) { treatmentType in
                            Text(treatmentType.asString())
                                .tag(treatmentType)
                        }
                    }
                } else {
                    HStack {
                        Text(Texts_TreatmentsView.type)
                        Spacer()
                        Text(viewModel.selectedType.asString())
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                DatePicker(selection: $viewModel.selectedDate, displayedComponents: [.date, .hourAndMinute]) {
                    Text(Texts_BgReadings.date)
                }

                if viewModel.showsNumericValueEditor {
                    HStack {
                        Text(Texts_TreatmentsView.value)
                        Spacer()
                        TextField(viewModel.valuePlaceholder, text: $viewModel.enteredValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color(.colorPrimary))
                            .frame(minWidth: 72, maxWidth: 96, alignment: .trailing)
                        Text(viewModel.unitText)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                if viewModel.showsNotesEditor {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Texts_TreatmentsView.notes)
                        TextEditor(text: $viewModel.enteredNotesValue)
                            .frame(minHeight: 120)
                            .padding(6)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color(.colorPrimary))
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
                HStack {
                    Text(Texts_TreatmentsView.enteredBy)
                    Spacer()
                    TextField(Texts_Common.unknown, text: $viewModel.enteredByValue)
                        .multilineTextAlignment(.trailing)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color(.colorPrimary))
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
        .alert(item: $viewModel.alertMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text(Texts_Common.Ok))
            )
        }
        .onChange(of: viewModel.selectedType) { _ in
            viewModel.validateSelectedDateIfNeeded()
        }
        .onChange(of: viewModel.selectedDate) { _ in
            viewModel.validateSelectedDateIfNeeded()
        }
    }

    @ViewBuilder private func editorFooterView() -> some View {
        if let helperText = viewModel.helperText {
            Text(helperText)
                .foregroundStyle(Color(.systemRed))
        }
    }
}
