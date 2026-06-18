//
//  TreatmentsView.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import Combine

struct TreatmentsView: View {
    // MARK: - private properties

    @StateObject private var viewModel: TreatmentsViewModel
    @State private var treatmentEditorState: TreatmentEditorState?

    // MARK: - initialization

    init(coreDataManager: CoreDataManager) {
        _viewModel = StateObject(wrappedValue: TreatmentsViewModel(coreDataManager: coreDataManager))
    }

    // MARK: - SwiftUI views

    var body: some View {
        TreatmentsListView(
            viewModel: viewModel,
            onAddTreatment: {
                treatmentEditorState = .add
            },
            onSelectTreatment: { treatment in
                treatmentEditorState = .edit(treatment)
            }
        )
        .sheet(item: $treatmentEditorState) { editorState in
            TreatmentEditorContainerView(
                coreDataManager: viewModel.coreDataManager,
                editorState: editorState,
                onSave: {
                    viewModel.reloadTreatments()
                    treatmentEditorState = nil
                },
                onCancel: {
                    treatmentEditorState = nil
                }
            )
        }
    }
}

struct TreatmentsListView: View {
    // MARK: - private properties

    @ObservedObject var viewModel: TreatmentsViewModel

    let onAddTreatment: () -> Void
    let onSelectTreatment: (TreatmentSnapshot) -> Void

    // MARK: - SwiftUI views

    var body: some View {
        List {
            Section(footer: Text(viewModel.selectedDateFooterText())) {
                DatePicker(selection: Binding(get: {
                    viewModel.selectedDate
                }, set: { newDate in
                    viewModel.selectedDateChanged(newDate)
                }), in: viewModel.datePickerRange(), displayedComponents: .date) {
                    HStack {
                        Text(Texts_BgReadings.date)
                        Spacer()
                        Text(viewModel.selectedDateDayName)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }
                .id(viewModel.datePickerReset)
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        TreatmentFilterChip(systemImage: "arrowtriangle.down.fill", tintColor: ConstantsGlucoseChart.bolusTreatmentColor, isSelected: viewModel.showBolusTreatments) {
                            viewModel.toggleBolusFilter()
                        }

                        TreatmentFilterChip(systemImage: "arrowtriangle.down.fill", tintColor: ConstantsGlucoseChart.bolusTreatmentColor, isSelected: viewModel.showSmallBolusTreatments, isEnabled: viewModel.showBolusTreatments, symbolScale: .medium, symbolFont: .system(size: 11, weight: .regular)) {
                            viewModel.toggleSmallBolusFilter()
                        }

                        TreatmentFilterChip(systemImage: "circle.fill", tintColor: ConstantsGlucoseChart.carbsTreatmentColor, isSelected: viewModel.showCarbsTreatments) {
                            viewModel.toggleCarbsFilter()
                        }

                        TreatmentFilterChip(systemImage: "drop.fill", tintColor: ConstantsGlucoseChart.bgCheckTreatmentColorInner, isSelected: viewModel.showBgCheckTreatments) {
                            viewModel.toggleBgCheckFilter()
                        }

                        if viewModel.showBasalFilter {
                            TreatmentFilterChip(systemImage: "chart.bar.fill", tintColor: ConstantsGlucoseChart.basalTreatmentColor, isSelected: viewModel.showBasalTreatments) {
                                viewModel.toggleBasalFilter()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if !viewModel.filteredTreatments.isEmpty {
                ForEach(viewModel.filteredTreatments, id: \.objectID) { treatment in
                    treatmentRow(for: treatment)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteTreatment(treatment)
                            } label: {
                                Label(Texts_Common.delete, systemImage: "trash")
                            }
                        }
                }
            } else {
                Text(Texts_TreatmentsView.noTreatmentsToShow)
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Texts_TreatmentsView.treatmentsTitle)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onAddTreatment) {
                    Image(systemName: "plus")
                }
                .tint(.yellow)
            }
        }
        .onAppear {
            viewModel.initializeViewIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: RunLoop.main)) { _ in
            viewModel.handleUserDefaultsDidChange()
        }
    }

    @ViewBuilder private func treatmentRow(for treatment: TreatmentSnapshot) -> some View {
        if treatment.isEditable {
            Button {
                onSelectTreatment(treatment)
            } label: {
                TreatmentRowView(treatment: treatment)
            }
            .buttonStyle(.plain)
        } else {
            TreatmentRowView(treatment: treatment)
        }
    }
}

private struct TreatmentRowView: View {
    let treatment: TreatmentSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Text(treatment.timeString)
                .font(.body)
                .foregroundStyle(treatment.primaryTextColor)
                .frame(minWidth: 58, alignment: .leading)

            Image(systemName: treatment.iconSystemName)
                .font(.system(size: treatment.iconSize, weight: .regular))
                .foregroundStyle(treatment.iconColor)
                .frame(width: 16)

            treatmentTitleView
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            if let valueText = treatment.valueText, let unitText = treatment.unitText {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(valueText)
                        .foregroundStyle(treatment.primaryTextColor)

                    Text(unitText)
                        .foregroundStyle(treatment.secondaryTextColor)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            if treatment.isEditable {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.colorTertiary))
            }
        }
    }

    private var treatmentTitleView: Text {
        var title = Text(treatment.typeText)
            .foregroundColor(Color(.colorPrimary))

        if let secondaryText = treatment.secondaryText {
            title = title + Text(" " + secondaryText)
                .font(.subheadline)
                .foregroundColor(Color(.colorTertiary))
        }

        return title
    }
}

private struct TreatmentFilterChip: View {
    let systemImage: String
    let tintColor: UIColor
    let isSelected: Bool
    let isEnabled: Bool
    let symbolScale: Image.Scale
    let symbolFont: Font?
    let action: () -> Void

    init(systemImage: String, tintColor: UIColor, isSelected: Bool, isEnabled: Bool = true, symbolScale: Image.Scale = .medium, symbolFont: Font? = nil, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tintColor = tintColor
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.symbolScale = symbolScale
        self.symbolFont = symbolFont
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(symbolFont)
                .imageScale(symbolScale)
                .frame(width: 20, height: 20)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(chipBackgroundColor)
                .foregroundStyle(chipForegroundColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(chipBorderColor.opacity(isEnabled || isSelected ? 1.0 : 0.6), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var displayAsSelected: Bool {
        isEnabled && isSelected
    }

    private var chipBackgroundColor: Color {
        if displayAsSelected {
            return Color(uiColor: tintColor).opacity(0.22)
        }

        return Color(uiColor: UIColor(white: 0.18, alpha: 1.0))
    }

    private var chipForegroundColor: Color {
        if displayAsSelected {
            return Color(uiColor: tintColor)
        }

        return Color(.colorSecondary)
    }

    private var chipBorderColor: Color {
        if displayAsSelected {
            return Color(uiColor: tintColor)
        }

        return Color(.colorSecondary)
    }
}
