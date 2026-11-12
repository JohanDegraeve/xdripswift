//
//  XDripWidget+Provider.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WidgetKit
import Foundation

extension XDripWidget {
    struct Provider: TimelineProvider {
        
        func placeholder(in context: Context) -> Entry {
            .placeholder
        }
        
        func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
            completion(context.isPreview ? .placeholder : Entry(date: .now, widgetState: getWidgetStateFromSharedUserDefaults()))
        }
        
        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
            let entry = Entry(date: .now, widgetState: getWidgetStateFromSharedUserDefaults())
                
            var entries = [entry]
            if let metrics = entry.widgetState.therapyMetrics {
                let deadlines = [metrics.iob.expiresAt, metrics.cob.expiresAt, metrics.iob.visibilityDeadline, metrics.cob.visibilityDeadline].compactMap { $0 }
                for date in Set(deadlines).sorted() where date > entry.date {
                    entries.append(Entry(date: date, widgetState: entry.widgetState))
                }
            }
            completion(.init(entries: entries, policy: .atEnd))
        }
    }
}


// MARK: - Helpers

extension XDripWidget.Provider {
    func getWidgetStateFromSharedUserDefaults() -> XDripWidget.Entry.WidgetState {
        
        let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
        
        let keepAliveDisabledMessage = sharedUserDefaults?.string(
            forKey: WidgetSharedUserDefaultsModel.keepAliveDisabledMessageKey(
                for: Bundle.main.mainAppBundleIdentifier
            )
        ).flatMap { $0.isEmpty ? nil : $0 }

        let encodedLatestReadings = sharedUserDefaults?.data(
            forKey: WidgetSharedUserDefaultsModel.widgetDataKey(
                for: Bundle.main.mainAppBundleIdentifier
            )
        )
        let data = WidgetSharedUserDefaultsModel.decodeForDisplay(encodedLatestReadings)
        let bgReadingDates = data.bgReadingDatesAsDouble.map { Date(timeIntervalSince1970: $0) }

        return Entry.WidgetState(bgReadingValues: data.bgReadingValues, bgReadingDates: bgReadingDates, isMgDl: data.isMgDl, slopeOrdinal: data.slopeOrdinal, deltaValueInUserUnit: data.deltaValueInUserUnit, urgentLowLimitInMgDl: data.urgentLowLimitInMgDl, lowLimitInMgDl: data.lowLimitInMgDl, highLimitInMgDl: data.highLimitInMgDl, urgentHighLimitInMgDl: data.urgentHighLimitInMgDl, dataSourceDescription: data.dataSourceDescription, followerPatientName: data.followerPatientName, keepAliveDisabledMessage: keepAliveDisabledMessage, aidStatus: data.aidStatus, therapyMetrics: data.therapyMetrics, allowStandByHighContrast: data.allowStandByHighContrast, forceStandByBigNumbers: data.forceStandByBigNumbers)
    }
}
