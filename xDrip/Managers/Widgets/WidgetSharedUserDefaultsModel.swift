//
//  WidgetSharedUserDefaultsModel.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// model of the data we'll store in the shared app group to pass from the watch app to the widgets
struct WidgetSharedUserDefaultsModel: Codable, Equatable {
    private static let widgetDataKeyPrefix = "widgetSharedUserDefaults"
    private static let keepAliveDisabledMessageKeyPrefix = "widgetKeepAliveDisabledMessage"

    static func widgetDataKey(for bundleIdentifier: String) -> String {
        "\(widgetDataKeyPrefix).\(bundleIdentifier)"
    }

    static func keepAliveDisabledMessageKey(for bundleIdentifier: String) -> String {
        "\(keepAliveDisabledMessageKeyPrefix).\(bundleIdentifier)"
    }

    var bgReadingValues: [Double]
    var bgReadingDatesAsDouble: [Double]
    var isMgDl: Bool
    var slopeOrdinal: Int
    var deltaValueInUserUnit: Double
    var urgentLowLimitInMgDl: Double
    var lowLimitInMgDl: Double
    var highLimitInMgDl: Double
    var urgentHighLimitInMgDl: Double
    var dataSourceDescription: String
    var followerPatientName: String?
    
    var aidStatus: AIDStatus?
    var therapyMetrics: TherapyMetricsSnapshot? = nil
    
    var allowStandByHighContrast: Bool
    var forceStandByBigNumbers: Bool

}

/// Remember completed publications, not requests which may still be queued or replaced.
struct CompanionPublicationCache<Value: Equatable> {
    private var value: Value?
    private var refreshAt: Date?

    func shouldPublish(_ value: Value, at date: Date, force: Bool = false) -> Bool {
        force || self.value != value || refreshAt.map { date >= $0 } == true
    }

    // Remember only the next future boundary. A successful refresh consumes earlier deadlines.
    mutating func record(_ value: Value, at date: Date, refreshDates: [Date]) {
        self.value = value
        refreshAt = refreshDates.filter { $0 > date }.min()
    }
}

extension TherapyMetricsSnapshot {
    /// Empty local snapshots get a new reference date on every fetch. That date cannot change
    /// their presentation. Keep all timestamps for metrics which can appear or expire.
    var publicationValue: Self {
        var value = self
        if value.iob.amount == nil, value.iob.expiresAt == nil, value.iob.visibilityDeadline == nil,
           value.iob.reason == .noTreatments || value.iob.reason == .disabled {
            value.iob.referenceDate = .distantPast
        }
        if value.cob.amount == nil, value.cob.expiresAt == nil, value.cob.visibilityDeadline == nil,
           value.cob.reason == .noTreatments || value.cob.reason == .disabled {
            value.cob.referenceDate = .distantPast
        }
        return value
    }
}

/// An unchanged payload can still need publishing when a reading or status ages. These are
/// checked on existing requests; no timer or additional background wake is introduced.
func companionPublicationRefreshDates(readingDate: Date?, aidStatus: AIDStatus?, therapyMetrics: TherapyMetricsSnapshot?) -> [Date] {
    var dates: [Date] = []
    if let readingDate {
        dates += [readingDate.addingTimeInterval(ConstantsWidgetExtension.bgReadingDateStaleInMinutes),
                  readingDate.addingTimeInterval(ConstantsWidgetExtension.bgReadingDateVeryStaleInMinutes)]
    }
    for date in [aidStatus?.statusUpdatedAt, aidStatus?.lastActivityAt].compactMap({ $0 }) {
        dates += [date.addingTimeInterval(-ConstantsHomeView.aidStatusFutureTolerance),
                  date.addingTimeInterval(ConstantsHomeView.loopShowWarningAfterMinutes),
                  date.addingTimeInterval(ConstantsHomeView.loopShowNoDataAfterMinutes)]
    }
    if let therapyMetrics {
        for metric in [therapyMetrics.iob, therapyMetrics.cob] {
            dates += [metric.referenceDate.addingTimeInterval(-60)]
            dates += [metric.expiresAt, metric.visibilityDeadline].compactMap { $0 }
        }
    }
    return dates
}
