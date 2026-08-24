//
//  StatisticsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Loads report analytics and period availability for the Statistics screen.
@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published var selectedPeriod: GlucoseReportPeriod = .ninety {
        didSet {
            guard oldValue != selectedPeriod else { return }
            loadAnalytics()
        }
    }
    @Published private(set) var analytics: GlucoseReportAnalytics?
    @Published private(set) var availablePeriods: [GlucoseReportPeriod: Bool] = [:]
    @Published private(set) var isLoading = true

    private let statisticsManager: StatisticsManager
    private var analyticsTask: Task<Void, Never>?

    init(statisticsManager: StatisticsManager) {
        self.statisticsManager = statisticsManager
    }

    /// Loads available periods before requesting analytics for the selected period.
    func load() {
        Task {
            isLoading = true
            let availability = await statisticsManager.availableReportPeriods()
            availablePeriods = availability
            if availability[selectedPeriod] != true {
                selectedPeriod = defaultPeriod(from: availability)
            } else {
                loadAnalytics()
            }
        }
    }

    func isPeriodAvailable(_ period: GlucoseReportPeriod) -> Bool {
        availablePeriods[period] ?? false
    }

    var selectablePeriods: [GlucoseReportPeriod] {
        GlucoseReportPeriod.allCases.filter { isPeriodAvailable($0) }
    }

    private func loadAnalytics() {
        analyticsTask?.cancel()
        let requestedPeriod = selectedPeriod
        let configuration = GlucoseReportConfiguration(
            patientName: UserDefaults.standard.reportPatientName,
            patientID: UserDefaults.standard.reportPatientID,
            period: selectedPeriod,
            aidPeriod: .notIncluded,
            paperSize: UserDefaults.standard.reportPaperSize,
            language: UserDefaults.standard.reportLanguage
        )

        analyticsTask = Task {
            isLoading = true
            let requestedAnalytics = await statisticsManager.reportAnalytics(for: configuration)
            guard !Task.isCancelled, selectedPeriod == requestedPeriod else { return }
            analytics = requestedAnalytics
            isLoading = false
        }
    }

    private func defaultPeriod(from availability: [GlucoseReportPeriod: Bool]) -> GlucoseReportPeriod {
        [.ninety, .sixty, .thirty, .seven, .oneEighty, .oneYear].first { availability[$0] == true } ?? .seven
    }
}
