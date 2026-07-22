//
//  GenerateReportView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

enum GenerateReportPresentation {
    case modal
    case embedded
}

struct GenerateReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GenerateReportViewModel
    private let presentation: GenerateReportPresentation

    init(statisticsManager: StatisticsManager, presentation: GenerateReportPresentation = .modal) {
        self.presentation = presentation
        _viewModel = StateObject(wrappedValue: GenerateReportViewModel(statisticsManager: statisticsManager))
    }

    @ViewBuilder var body: some View {
        switch presentation {
        case .modal:
            NavigationStack {
                reportForm
                    .navigationTitle(Texts_Common.reportGenerateTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(Texts_Common.Cancel) {
                                dismiss()
                            }
                            .foregroundStyle(.primary)
                            .disabled(viewModel.isGenerating)
                        }
                    }
            }
        case .embedded:
            reportForm
        }
    }

    private var reportForm: some View {
        Form {
            patientSection
            optionsSection
        }
        .disabled(viewModel.isGenerating)
        .overlay {
            if viewModel.isGenerating {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(Texts_Common.reportGeneratingStatus)
                            .font(.headline)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .task {
            viewModel.loadAvailability()
        }
        .alert(Texts_Common.reportGenerationFailedTitle, isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(Texts_Common.Ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $viewModel.generatedReport) { report in
            NavigationStack {
                GlucoseReportPreviewView(report: report)
            }
        }
    }

    private var patientSection: some View {
        Section {
            NavigationLink {
                ReportTextFieldEditView(
                    title: Texts_Common.reportPatientName,
                    placeholder: Texts_Common.reportPatientNamePlaceholder,
                    text: $viewModel.patientName,
                    capitalization: .words
                )
            } label: {
                ReportSettingRow(title: Texts_Common.reportPatientName, value: viewModel.patientName, placeholder: Texts_Common.reportNotSet)
            }

            NavigationLink {
                ReportTextFieldEditView(
                    title: Texts_Common.reportPatientID,
                    placeholder: Texts_Common.reportPatientIDPlaceholder,
                    text: $viewModel.patientID,
                    capitalization: .characters
                )
            } label: {
                ReportSettingRow(title: Texts_Common.reportPatientID, value: viewModel.patientID, placeholder: Texts_Common.reportNotSet)
            }
        } header: {
            Text(Texts_Common.reportPatientSection)
        } footer: {
            Text(Texts_Common.reportPatientFooter)
        }
    }

    private var optionsSection: some View {
        Section {
            NavigationLink {
                ReportPeriodPickerView(
                    selectedPeriod: $viewModel.selectedPeriod,
                    isPeriodAvailable: viewModel.isPeriodAvailable
                )
            } label: {
                ReportSettingRow(title: Texts_Common.reportPeriod, value: viewModel.selectedPeriod.optionTitle)
            }
            .disabled(viewModel.isLoadingAvailability)

            NavigationLink {
                ReportPaperSizePickerView(paperSize: $viewModel.paperSize)
            } label: {
                ReportSettingRow(title: Texts_Common.reportPaperSize, value: viewModel.paperSize.title)
            }

            NavigationLink {
                ReportLanguagePickerView(language: $viewModel.language)
            } label: {
                ReportSettingRow(title: Texts_Common.reportLanguage, value: viewModel.language.title)
            }

            NavigationLink {
                ReportPasswordEditView(password: $viewModel.passwordToOpen)
            } label: {
                ReportSettingRow(title: Texts_Common.reportPasswordToOpen, value: viewModel.passwordToOpen, placeholder: Texts_Common.reportNone, isPassword: true)
            }
        } header: {
            Text(Texts_Common.reportOptions)
        } footer: {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 6) {
                    passwordStatusIcon
                    Text(viewModel.hasPasswordToOpen ? Texts_Common.reportWillBePasswordProtected : Texts_Common.reportWillNotBePasswordProtected)
                }

                generateButton
            }
            .padding(.top, 0)
        }
    }

    private var generateButton: some View {
        Button {
            viewModel.generateReport()
        } label: {
            Text(Texts_Common.reportGenerateTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(.systemBlue))
        .disabled(!viewModel.isPeriodAvailable(viewModel.selectedPeriod) || viewModel.isLoadingAvailability)
    }

    private var passwordStatusIcon: some View {
        if viewModel.hasPasswordToOpen {
            Image(systemName: "lock.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "lock.slash")
                .foregroundStyle(Color(.colorTertiary))
        }
    }
}

private struct ReportSettingRow: View {
    let title: String
    let value: String
    var placeholder: String?
    var isPassword = false

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(displayValue)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.trailing)
        }
    }

    private var displayValue: String {
        guard !value.isEmpty else {
            return placeholder ?? ""
        }

        guard isPassword else {
            return value
        }

        return String(repeating: "•", count: min(max(value.count, 6), 12))
    }
}

private struct ReportTextFieldEditView: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let capitalization: TextInputAutocapitalization

    var body: some View {
        Form {
            Section {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReportPasswordEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var password: String
    @State private var passwordEntry: String
    @State private var confirmationEntry: String

    init(password: Binding<String>) {
        _password = password
        _passwordEntry = State(initialValue: password.wrappedValue)
        _confirmationEntry = State(initialValue: password.wrappedValue)
    }

    var body: some View {
        Form {
            Section {
                SecureField(Texts_Common.reportPasswordFieldPlaceholder, text: $passwordEntry)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField(Texts_Common.reportPasswordConfirmationPlaceholder, text: $confirmationEntry)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text(Texts_Common.reportPasswordFooter)
            }
        }
        .navigationTitle(Texts_Common.reportPasswordToOpen)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Texts_Common.Ok) {
                    password = passwordEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }
                .disabled(!passwordIsValid)
            }
        }
    }

    private var passwordIsValid: Bool {
        let trimmedPassword = passwordEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirmation = confirmationEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedPassword.isEmpty && trimmedPassword == trimmedConfirmation
    }
}

private struct ReportPeriodPickerView: View {
    @Binding var selectedPeriod: GlucoseReportPeriod
    let isPeriodAvailable: (GlucoseReportPeriod) -> Bool
    private let dateRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        List {
            ForEach(GlucoseReportPeriod.allCases) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(period.optionTitle)
                                    .foregroundStyle(Color(.colorPrimary))

                                if isPeriodAvailable(period) {
                                    Text("(\(dateRangeText(for: period)))")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(.colorSecondary))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                } else {
                                    Text("(\(Texts_Common.reportNotEnoughData))")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color(.colorSecondary))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .opacity(isPeriodAvailable(period) ? 1 : 0.45)
                }
                .disabled(!isPeriodAvailable(period))
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(Texts_Common.reportPeriod)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dateRangeText(for period: GlucoseReportPeriod) -> String {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -period.rawValue, to: endDate) ?? endDate
        return "\(dateRangeFormatter.string(from: startDate)) - \(dateRangeFormatter.string(from: endDate))"
    }

}

private struct ReportPaperSizePickerView: View {
    @Binding var paperSize: GlucoseReportPaperSize

    var body: some View {
        List {
            ForEach(GlucoseReportPaperSize.allCases) { size in
                Button {
                    paperSize = size
                } label: {
                    selectionRow(title: size.title, isSelected: paperSize == size)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(Texts_Common.reportPaperSize)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReportLanguagePickerView: View {
    @Binding var language: GlucoseReportLanguage

    var body: some View {
        List {
            ForEach(GlucoseReportLanguage.allCases) { reportLanguage in
                Button {
                    language = reportLanguage
                } label: {
                    selectionRow(title: reportLanguage.title, isSelected: language == reportLanguage)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(Texts_Common.reportLanguage)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func selectionRow(title: String, isSelected: Bool) -> some View {
    HStack {
        Text(title)
            .foregroundStyle(Color(.colorPrimary))
        Spacer()
        if isSelected {
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
        }
    }
}
