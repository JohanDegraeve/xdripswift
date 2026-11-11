//
//  DirectWatchAlertsView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 16/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Watch-local choices stay available without the phone. The phone supplies the daily
/// thresholds, while the Watch evaluates the current local time and communication window.
struct DirectWatchAlertsView: View {
    @ObservedObject var collector: DirectWatchCollector

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            List {
                Section {
                    Toggle(isOn: Binding(get: { collector.urgentLowNotificationsEnabled },
                                         set: { collector.setUrgentLowNotificationsEnabled($0) })) {
                        alertLabel(TextsDirectWatch.urgentLow, schedule: collector.configuration?.urgentLowSchedule, at: timeline.date)
                    }
                    Toggle(isOn: Binding(get: { collector.lowNotificationsEnabled },
                                         set: { collector.setLowNotificationsEnabled($0) })) {
                        alertLabel(TextsDirectWatch.low, schedule: collector.configuration?.lowSchedule, at: timeline.date)
                    }
                    Toggle(TextsDirectWatch.missedReadings, isOn: Binding(
                        get: { collector.missedReadingNotificationsEnabled },
                        set: { collector.setMissedReadingNotificationsEnabled($0) }
                    ))
                } footer: {
                    Text(TextsDirectWatch.missedReadingsExplanation + "\n\n" + TextsDirectWatch.alertExplanation)
                        .font(.footnote)
                        .foregroundStyle(.colorSecondary)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(.colorPrimary)
        }
        .navigationTitle(TextsDirectWatch.alerts)
    }

    private func alertLabel(_ title: String, schedule: [DirectWatchAlertEntry]?, at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(threshold(schedule, at: date))
                .font(.footnote)
                .foregroundStyle(.colorSecondary)
        }
    }

    private func threshold(_ schedule: [DirectWatchAlertEntry]?, at date: Date) -> String {
        guard let entry = DirectWatchAlertEntry.current(in: schedule, at: date) else { return TextsDirectWatch.scheduleUnavailable }
        return collector.configuration?.isMgDl == false
            ? String(format: "< %.1f mmol/L", entry.threshold / 18)
            : String(format: "< %.0f mg/dL", entry.threshold)
    }
}
