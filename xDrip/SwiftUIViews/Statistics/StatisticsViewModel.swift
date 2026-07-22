//
//  StatisticsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

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

    private let analyticsService: GlucoseReportAnalyticsService

    init(coreDataManager: CoreDataManager) {
        analyticsService = GlucoseReportAnalyticsService(coreDataManager: coreDataManager)
    }

    func load() {
        Task {
            isLoading = true
            let availability = await analyticsService.availablePeriods()
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
        let configuration = GlucoseReportConfiguration(
            patientName: UserDefaults.standard.reportPatientName,
            patientID: UserDefaults.standard.reportPatientID,
            period: selectedPeriod,
            paperSize: UserDefaults.standard.reportPaperSize,
            language: UserDefaults.standard.reportLanguage
        )

        Task {
            isLoading = true
            analytics = await analyticsService.analytics(for: configuration)
            isLoading = false
        }
    }

    private func defaultPeriod(from availability: [GlucoseReportPeriod: Bool]) -> GlucoseReportPeriod {
        [.ninety, .sixty, .thirty, .seven, .oneEighty, .oneYear].first { availability[$0] == true } ?? .seven
    }
}
