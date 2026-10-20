//
//  DirectWatchStatusBanner.swift
//  xDrip
//
//  Created by Paul Plant on 13/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Reading freshness determines status. Resume/connection time determines the elapsed counter.
struct DirectWatchStatusBanner: View {
    let isConfigured: Bool
    let isSuspended: Bool
    var isPaused = false
    let latestReadingAt: Date?
    var lastConnectedAt: Date? = nil
    var resumedAt: Date? = nil
    var pausedAt: Date? = nil
    let now: Date

    private var status: DirectWatchReadingStatus {
        DirectWatchReadingStatus(isConfigured: isConfigured, isSuspended: isSuspended,
                                 latestReadingAt: latestReadingAt, now: now, isPaused: isPaused,
                                 resumedAt: resumedAt, lastConnectedAt: lastConnectedAt)
    }

    private var color: Color { ConstantsDirectWatch.statusColor(for: status) }

    var body: some View {
        #if os(watchOS)
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: ConstantsDirectWatch.watchSymbol(for: status))
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Text(status.title)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            counterRow
        }
        .font(.system(size: 17))
        .padding(.horizontal, 7)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackgroundColor, in: RoundedRectangle(cornerRadius: 10))
        #else
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: ConstantsDirectWatch.watchSymbol(for: status))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(status.title)
                    .font(.headline)
                    .foregroundStyle(Color(.colorPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                counterRow
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The Form supplies standard 16-point horizontal insets around this content.
        .padding(.vertical, 14)
        #endif
    }

    @ViewBuilder private var counterRow: some View {
        if isConfigured {
            #if os(watchOS)
            ScaledDataSourceRow(height: 22) {
                if isPaused {
                    Text(TextsDirectWatch.pausedSince(pausedAt))
                        .foregroundStyle(Color("colorSecondary"))
                        .lineLimit(1)
                } else { counterLeadingText }
            } trailing: {
                if !isPaused { counterTrailingText }
            }
            #else
            if isPaused {
                Text(TextsDirectWatch.pausedSince(pausedAt))
                    .foregroundStyle(Color("colorSecondary"))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 5) {
                    counterLeadingText
                    Spacer(minLength: 6)
                    counterTrailingText
                }
                .lineLimit(1)
            }
            #endif
        }
    }

    private var counterLeadingText: some View {
        Text(counterReference.map { date in
            Calendar.current.isDate(date, inSameDayAs: now)
                ? date.formatted(date: .omitted, time: .shortened)
                : date.formatted(.dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits))
        } ?? "--:--")
        .foregroundStyle(.secondary)
    }

    private var counterTrailingText: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .accessibilityHidden(true)
            Text(counterText).monospacedDigit()
        }
        .foregroundStyle(counterColor)
    }

    private var counterReference: Date? {
        DirectWatchCollectionPolicy.counterReference(resumedAt: resumedAt, lastConnectedAt: lastConnectedAt)
    }

    private var counterText: String {
        guard let elapsed = DirectWatchCollectionPolicy.counterElapsed(resumedAt: resumedAt, lastConnectedAt: lastConnectedAt,
                                                                        isPaused: isPaused, now: now) else { return "--:--" }
        let seconds = Int(elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var rowBackgroundColor: Color {
        #if os(watchOS)
        return color.opacity(0.25)
        #else
        switch status {
        case .current: return ConstantsUI.activeRowBackgroundColor
        case .connecting, .delayed, .suspended: return ConstantsUI.connectingRowBackgroundColor
        case .waiting, .overdue: return Color.red.opacity(0.12)
        case .off, .paused: return Color(.secondarySystemGroupedBackground)
        }
        #endif
    }

    private var counterColor: Color {
        guard !isPaused, let counterReference else { return ConstantsDirectWatch.statusColor(for: .paused) }
        let age = DirectWatchReadingStatus(age: now.timeIntervalSince(counterReference))
        // A fresh resume is orange while waiting. It must still reach the overdue colour
        // if no connection arrives, rather than keeping an arbitrarily old counter orange.
        if age == .current { return status == .connecting ? .orange : .secondary }
        return ConstantsDirectWatch.statusColor(for: age)
    }


}


/// The same action row appears on the phone and Watch.
struct DirectWatchCollectionControlButton: View {
    let isPaused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isPaused ? ConstantsDirectWatch.resumeSymbol : ConstantsDirectWatch.pauseSymbol)
                    .font(.system(size: 22))
                Text(isPaused ? TextsDirectWatch.resume : TextsDirectWatch.pause)
                    .font(.system(size: 17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .buttonStyle(DirectWatchButtonStyle())
    }
}

/// All collection actions share the same muted blue surface, including disabled actions.
struct DirectWatchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color("colorPrimary"))
            .padding(.horizontal, 7)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(ConstantsDirectWatch.buttonBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}
