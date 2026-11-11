//
//  DirectWatchCollectedReadingsView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 14/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Show the full local reading history, including readings already synced to the phone.
struct DirectWatchCollectedReadingsView: View {
    @EnvironmentObject private var watchState: WatchStateModel
    @ObservedObject var collector: DirectWatchCollector

    // Use the requested 24-hour HH:mm clock in the device's current time zone.
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        // Show the full local store, including older readings still waiting for phone sync.
        let readings = collector.readings.sorted { $0.measuredAt > $1.measuredAt }
        let referenced = Set(readings.compactMap(\.collectionSessionID))
        let oldestCollectedAt = readings.compactMap(\.collectedAt).min() ?? .distantPast
        let sessions = collector.collectionSessions.filter {
            referenced.contains($0.id) || $0.startedAt >= oldestCollectedAt
        }.reversed()
        let ungroupedReadings = readings.filter { $0.collectionSessionID == nil }
        List {
            ForEach(Array(sessions)) { session in
                let sessionReadings = readings.filter { $0.collectionSessionID == session.id }
                let containsFirstReading = session.firstReadingID.map { sessionReadings.last?.id == $0 } ?? true
                let showsStart = containsFirstReading && !collector.readings.contains {
                    $0.collectionSessionID == session.id && $0.measuredAt < (sessionReadings.last?.measuredAt ?? .distantPast)
                }
                // Each collection session has one card, with simple rows inside it.
                Section {
                    VStack(spacing: 6) {
                        // Keep the whole session newest first, including its boundary events.
                        if session.endedAt != nil {
                            sessionBoundary(session, ending: true)
                                .padding(.top, 8)
                        }
                        readingRows(sessionReadings, session: session, showsStart: showsStart)
                        if sessionReadings.isEmpty {
                            Text(TextsDirectWatch.noCollectedReadings)
                                .foregroundStyle(.secondary)
                        }
                        // Hide the start event when the session's earliest readings have expired from the local store.
                        if showsStart {
                            sessionBoundary(session, ending: false)
                                .padding(.bottom, 8)
                        }
                    }
                }
            }
            // Older app versions did not save sessions. Keep those readings separate
            // without inventing start or stop events for them.
            if !ungroupedReadings.isEmpty {
                Section {
                    VStack(spacing: 6) {
                        readingRows(ungroupedReadings, session: nil)
                    }
                }
            }
            if readings.isEmpty && sessions.isEmpty {
                Section {
                    Text(TextsDirectWatch.noCollectedReadings)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(TextsDirectWatch.collectedReadings)
    }

    private func readingRows(_ readings: [DirectWatchReading], session: DirectWatchCollectionSession?, showsStart: Bool = false) -> some View {
        ForEach(readings) { reading in
            ScaledDataSourceRow(height: 24) {
                Text(Self.timestampFormatter.string(from: reading.measuredAt))
                    .monospacedDigit()
            } trailing: {
                Text("\(reading.mgDl.mgDlToMmolAndToString(mgDl: watchState.isMgDl)) \(watchState.bgUnitString())")
                    .monospacedDigit()
            }
            .font(.system(size: 17))
            .foregroundStyle(.colorPrimary)
            // This interval separates the reading above from its earlier reading or resume below.
            if (showsStart || reading.id != readings.last?.id),
               let session, let interval = session.intervalBefore(reading, in: collector.readings) {
                let status = DirectWatchReadingStatus(age: interval)
                Text(TextsDirectWatch.readingGap(interval))
                    .font(.system(size: 15))
                    .foregroundStyle(ConstantsDirectWatch.statusColor(for: status))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func sessionBoundary(_ session: DirectWatchCollectionSession, ending: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ending ? ConstantsDirectWatch.pauseSymbol : ConstantsDirectWatch.resumeSymbol)
            Text(TextsDirectWatch.sessionBoundary(session, ending: ending))
        }
        .font(.system(size: 15))
        .foregroundStyle(.yellow)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
