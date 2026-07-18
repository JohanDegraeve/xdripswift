//
//  TreatmentsView.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

/// Owns the treatment list model and presents the add/edit sheet.
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

/// Displays treatments for one day with the persisted treatment filters.
struct TreatmentsListView: View {
    // MARK: - private properties

    @ObservedObject var viewModel: TreatmentsViewModel
    @State private var showScrollToTopButton = false
    private let topScrollAnchorID = "treatmentsTop"
    private let scrollToTopButtonThresholdIndex = 4

    let onAddTreatment: () -> Void
    let onSelectTreatment: (TreatmentSnapshot) -> Void

    // MARK: - SwiftUI views

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .bottomTrailing) {
                List {
                    Section {
                        TreatmentsControlsCard(viewModel: viewModel)
                            .id(topScrollAnchorID)
                            .onAppear { showScrollToTopButton = false }
                            .onDisappear { showScrollToTopButton = true }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if !viewModel.filteredTreatments.isEmpty {
                        ForEach(Array(viewModel.filteredTreatments.enumerated()), id: \.element.objectID) { index, treatment in
                            treatmentRow(for: treatment)
                                .onAppear {
                                    if index >= scrollToTopButtonThresholdIndex {
                                        showScrollToTopButton = true
                                    }
                                }
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
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)

                if showScrollToTopButton {
                    Button {
                        withAnimation {
                            scrollProxy.scrollTo(topScrollAnchorID, anchor: .top)
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.yellow)
                            .frame(width: 48, height: 48)
                            .background(Color(.secondarySystemGroupedBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showScrollToTopButton)
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
            .onReceive(
                NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: RunLoop.main)
            ) { _ in
                viewModel.handleUserDefaultsDidChange()
            }
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

/// Persistent top controls for date selection and treatment filters.
private struct TreatmentsControlsCard: View {
    @ObservedObject var viewModel: TreatmentsViewModel

    var body: some View {
        VStack(spacing: 0) {
            DatePicker(selection: Binding(get: {
                viewModel.selectedDate
            }, set: { newDate in
                viewModel.selectedDateChanged(newDate)
            }), in: ...latestSelectableDate, displayedComponents: .date) {
                HStack {
                    Text(Texts_BgReadings.date)
                    Spacer()
                    Text(viewModel.selectedDateDayName)
                        .foregroundStyle(Color(.colorSecondary))
                }
            }
            .id(viewModel.datePickerReset)
            .tint(Color(.colorSecondary))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(Color(.separator))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    TreatmentFilterChip(
                        systemImage: "arrowtriangle.down.fill",
                        tintColor: ConstantsGlucoseChart.bolusTreatmentColor,
                        isSelected: viewModel.showBolusTreatments
                    ) {
                        viewModel.toggleBolusFilter()
                    }

                    TreatmentFilterChip(
                        systemImage: "arrowtriangle.down.fill",
                        tintColor: ConstantsGlucoseChart.bolusTreatmentColor,
                        isSelected: viewModel.showSmallBolusTreatments,
                        isEnabled: viewModel.showBolusTreatments,
                        symbolScale: .medium,
                        symbolFont: .system(size: 11, weight: .regular)
                    ) {
                        viewModel.toggleSmallBolusFilter()
                    }

                    TreatmentFilterChip(
                        systemImage: "circle.fill",
                        tintColor: ConstantsGlucoseChart.carbsTreatmentColor,
                        isSelected: viewModel.showCarbsTreatments
                    ) {
                        viewModel.toggleCarbsFilter()
                    }

                    TreatmentFilterChip(
                        systemImage: "drop.fill",
                        tintColor: ConstantsGlucoseChart.bgCheckTreatmentColorInner,
                        isSelected: viewModel.showBgCheckTreatments
                    ) {
                        viewModel.toggleBgCheckFilter()
                    }

                    TreatmentFilterChip(
                        systemImage: "note.text",
                        tintColor: ConstantsGlucoseChart.noteTreatmentColor,
                        isSelected: viewModel.showNoteTreatments
                    ) {
                        viewModel.toggleNoteFilter()
                    }

                    if viewModel.showBasalFilter {
                        TreatmentFilterChip(
                            systemImage: "chart.bar.fill",
                            tintColor: ConstantsGlucoseChart.basalTreatmentColor,
                            isSelected: viewModel.showBasalTreatments
                        ) {
                            viewModel.toggleBasalFilter()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Last selectable timestamp for the date-only picker.
    /// This keeps tomorrow disabled without making today's selected value invalid by a few milliseconds.
    private var latestSelectableDate: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Date().toMidnight()) ?? Date()
    }
}

/// One treatment row using the same symbols and units as the glucose chart.
private struct TreatmentRowView: View {
    let treatment: TreatmentSnapshot

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(treatment.timeString)
                    .font(.body)
                    .foregroundStyle(treatment.primaryTextColor)
                    .frame(minWidth: 58, alignment: .leading)

                Image(systemName: treatment.iconSystemName)
                    .font(.system(size: treatment.iconSize, weight: .regular))
                    .foregroundStyle(treatment.iconColor)
                    .frame(width: 16)
            }

            treatmentTitleView
                .lineLimit(treatment.treatmentType == .Note ? 2 : 1)
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
            let separator = treatment.treatmentType == .Note ? ": " : " "
            title = title + Text(separator + secondaryText) // swiftlint:disable:this shorthand_operator
                .font(.subheadline)
                .foregroundColor(Color(.colorTertiary))
        }

        return title
    }
}

/// Compact native button used to enable or disable one treatment category.
private struct TreatmentFilterChip: View {
    let systemImage: String
    let tintColor: Color
    let isSelected: Bool
    let isEnabled: Bool
    let symbolScale: Image.Scale
    let symbolFont: Font?
    let action: () -> Void

    init(
        systemImage: String,
        tintColor: Color,
        isSelected: Bool,
        isEnabled: Bool = true,
        symbolScale: Image.Scale = .medium,
        symbolFont: Font? = nil,
        action: @escaping () -> Void
    ) {
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
            ZStack(alignment: .bottomTrailing) {
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

                if displayAsSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, .green)
                        .offset(x: 4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var displayAsSelected: Bool {
        isEnabled && isSelected
    }

    private var chipBackgroundColor: Color {
        if displayAsSelected {
            return tintColor.opacity(0.22)
        }

        return Color(white: 0.14)
    }

    private var chipForegroundColor: Color {
        if displayAsSelected {
            return tintColor
        }

        return Color(.colorSecondary)
    }

    private var chipBorderColor: Color {
        if displayAsSelected {
            return tintColor
        }

        return Color(.colorSecondary)
    }
}
