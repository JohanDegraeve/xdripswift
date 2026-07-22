//
//  GenerateReportView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct GenerateReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GenerateReportViewModel

    init(statisticsManager: StatisticsManager) {
        _viewModel = StateObject(wrappedValue: GenerateReportViewModel(statisticsManager: statisticsManager))
    }

    var body: some View {
        NavigationStack {
            Form {
                patientSection
                optionsSection
                generateSection
            }
            .navigationTitle("Generate Report")
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
            .disabled(viewModel.isGenerating)
            .overlay {
                if viewModel.isGenerating {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Generating clinical report...")
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
            .alert("Report generation failed", isPresented: Binding(
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
    }

    private var patientSection: some View {
        Section {
            NavigationLink {
                ReportTextFieldEditView(
                    title: "Patient Name",
                    placeholder: "Patient name",
                    text: $viewModel.patientName,
                    capitalization: .words
                )
            } label: {
                ReportSettingRow(title: "Patient Name", value: viewModel.patientName, placeholder: "Not Set")
            }

            NavigationLink {
                ReportTextFieldEditView(
                    title: "Patient ID",
                    placeholder: "Medical record / patient ID",
                    text: $viewModel.patientID,
                    capitalization: .characters
                )
            } label: {
                ReportSettingRow(title: "Patient ID", value: viewModel.patientID, placeholder: "Not Set")
            }
        } header: {
            Text("Patient")
        } footer: {
            Text("Patient details are stored locally on this device and printed in the report header.")
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
                ReportSettingRow(title: "Report Period", value: viewModel.selectedPeriod.clinicalTitle)
            }
            .disabled(viewModel.isLoadingAvailability)

            NavigationLink {
                ReportPaperSizePickerView(paperSize: $viewModel.paperSize)
            } label: {
                ReportSettingRow(title: "Paper Size", value: viewModel.paperSize.title)
            }

            NavigationLink {
                ReportLanguagePickerView(language: $viewModel.language)
            } label: {
                ReportSettingRow(title: "Language", value: viewModel.language.title)
            }

            NavigationLink {
                ReportPasswordEditView(password: $viewModel.passwordToOpen)
            } label: {
                ReportSettingRow(title: "Password to Open", value: viewModel.passwordToOpen, placeholder: "None", isPassword: true)
            }
        } header: {
            Text("Report Options")
        } footer: {
            if viewModel.hasPasswordToOpen {
                HStack(spacing: 6) {
                    Image(systemName: "lock.circle.fill")
                        .foregroundStyle(.green)
                    Text("Report will be password protected")
                }
            }
        }
    }

    private var generateSection: some View {
        Button {
            viewModel.generateReport()
        } label: {
            Text("Generate Report")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(.systemBlue))
        .disabled(!viewModel.isPeriodAvailable(viewModel.selectedPeriod) || viewModel.isLoadingAvailability)
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .listRowBackground(Color.clear)
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
                SecureField("Password to open PDF", text: $passwordEntry)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Enter password again", text: $confirmationEntry)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("This password is only used for the next generated PDF and is not stored.")
            }
        }
        .navigationTitle("Password to Open")
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
                        VStack(alignment: .leading, spacing: 3) {
                            Text(period.clinicalTitle)
                                .foregroundStyle(Color(.colorPrimary))

                            Text(periodSubtitle(for: period))
                                .font(.caption)
                                .foregroundStyle(Color(.colorTertiary))
                        }

                        Spacer()

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
        .navigationTitle("Report Period")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dateRangeText(for period: GlucoseReportPeriod) -> String {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -period.rawValue, to: endDate) ?? endDate
        return "\(dateRangeFormatter.string(from: startDate)) - \(dateRangeFormatter.string(from: endDate))"
    }

    private func periodSubtitle(for period: GlucoseReportPeriod) -> String {
        isPeriodAvailable(period) ? dateRangeText(for: period) : "Not enough data"
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
        .navigationTitle("Paper Size")
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
        .navigationTitle("Language")
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
