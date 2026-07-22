//
//  GenerateReportViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

@MainActor
final class GenerateReportViewModel: ObservableObject {
    @Published var patientName: String {
        didSet {
            UserDefaults.standard.reportPatientName = patientName
        }
    }
    @Published var patientID: String {
        didSet {
            UserDefaults.standard.reportPatientID = patientID
        }
    }
    @Published var selectedPeriod: GlucoseReportPeriod {
        didSet {
            UserDefaults.standard.reportPeriod = selectedPeriod
        }
    }
    @Published var paperSize: GlucoseReportPaperSize {
        didSet {
            UserDefaults.standard.reportPaperSize = paperSize
        }
    }
    @Published var language: GlucoseReportLanguage {
        didSet {
            UserDefaults.standard.reportLanguage = language
        }
    }
    @Published var passwordToOpen = ""
    @Published private(set) var availablePeriods: [GlucoseReportPeriod: Bool] = [:]
    @Published private(set) var isLoadingAvailability = true
    @Published private(set) var isGenerating = false
    @Published var generatedReport: GlucoseReport?
    @Published var errorMessage: String?

    private let statisticsManager: StatisticsManager
    private let pdfGenerator = GlucoseReportPDFGenerator()

    init(statisticsManager: StatisticsManager) {
        self.statisticsManager = statisticsManager
        patientName = UserDefaults.standard.reportPatientName
        patientID = UserDefaults.standard.reportPatientID
        selectedPeriod = UserDefaults.standard.reportPeriod
        paperSize = UserDefaults.standard.reportPaperSize
        language = UserDefaults.standard.reportLanguage
    }

    func loadAvailability() {
        Task {
            isLoadingAvailability = true
            let availability = await statisticsManager.availableReportPeriods()
            availablePeriods = availability
            if availability[selectedPeriod] != true {
                selectedPeriod = defaultPeriod(from: availability)
            }
            isLoadingAvailability = false
        }
    }

    func generateReport() {
        guard !isGenerating else { return }

        Task {
            isGenerating = true
            errorMessage = nil

            let configuration = GlucoseReportConfiguration(
                patientName: patientName.trimmingCharacters(in: .whitespacesAndNewlines),
                patientID: patientID.trimmingCharacters(in: .whitespacesAndNewlines),
                period: selectedPeriod,
                paperSize: paperSize,
                language: language
            )

            UserDefaults.standard.reportPatientName = configuration.patientName
            UserDefaults.standard.reportPatientID = configuration.patientID
            UserDefaults.standard.reportPeriod = configuration.period
            UserDefaults.standard.reportPaperSize = configuration.paperSize
            UserDefaults.standard.reportLanguage = configuration.language

            let analytics = await statisticsManager.reportAnalytics(for: configuration)
            let generatedAt = Date()

            do {
                let pdfURL = try await pdfGenerator.generatePDF(configuration: configuration, analytics: analytics, generatedAt: generatedAt)
                generatedReport = GlucoseReport(
                    configuration: configuration,
                    generatedAt: generatedAt,
                    analytics: analytics,
                    pdfURL: pdfURL,
                    passwordToOpen: trimmedPasswordToOpen
                )
            } catch {
                errorMessage = error.localizedDescription
            }

            isGenerating = false
        }
    }

    func isPeriodAvailable(_ period: GlucoseReportPeriod) -> Bool {
        availablePeriods[period] ?? false
    }

    var hasPasswordToOpen: Bool {
        trimmedPasswordToOpen != nil
    }

    private var trimmedPasswordToOpen: String? {
        let trimmedPassword = passwordToOpen.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPassword.isEmpty ? nil : trimmedPassword
    }

    private func defaultPeriod(from availability: [GlucoseReportPeriod: Bool]) -> GlucoseReportPeriod {
        [.ninety, .sixty, .thirty, .seven, .oneEighty, .oneYear].first { availability[$0] == true } ?? .seven
    }
}
