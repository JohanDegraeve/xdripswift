//
//  LandscapeValueView.swift
//  xdrip
//
//  Created by Johan Degraeve on 24/12/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Full-screen glucose value used by the locked landscape Home presentation.
///
/// It consumes the same formatted glucose state as portrait Home, so value age, delta, colors and
/// stale-reading treatment remain consistent between orientations.
struct LandscapeValueView: View {

    // MARK: - Properties

    let glucoseState: RootHomeGlucoseState
    @State private var currentDate = Date()

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var showsClock: Bool { UserDefaults.standard.showClockWhenScreenIsLocked }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showsClock {
                    clockView(availableHeight: geometry.size.height)
                }

                glucoseContent(availableSize: geometry.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .colorScheme(.dark)
        .onReceive(clockTimer) { date in
            guard showsClock else { return }

            currentDate = date
        }
    }

    // MARK: - Views

    /// Optional clock sized from the available landscape height.
    private func clockView(availableHeight: CGFloat) -> some View {
        Text(currentDate.formatted(date: .omitted, time: .shortened))
            .font(.system(size: max(34, availableHeight * 0.16), weight: .heavy))
            .foregroundStyle(ConstantsAppColors.clockText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.2)
            .frame(maxWidth: .infinity)
    }

    /// Glucose age, delta and main value scaled to the complete remaining area.
    private func glucoseContent(availableSize: CGSize) -> some View {
        VStack(spacing: -10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                minutesView
                    .frame(maxWidth: .infinity, alignment: .leading)

                deltaView
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: topRowFontSize(availableHeight: availableSize.height)))
            .lineLimit(1)
            .minimumScaleFactor(0.25)

            Text(glucoseState.valueText)
                .font(.system(size: valueFontSize(availableSize: availableSize), weight: .regular))
                .foregroundStyle(glucoseState.valueColor)
                .strikethrough(glucoseState.valueHasStrikethrough, color: glucoseState.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var minutesView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(glucoseState.minutesText)
                .foregroundStyle(glucoseState.minutesColor)
                .monospacedDigit()

            Text(glucoseState.minutesAgoText)
                .foregroundStyle(ConstantsAppColors.secondaryText)
        }
    }

    private var deltaView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(glucoseState.deltaText)
                .foregroundStyle(glucoseState.deltaColor)
                .monospacedDigit()

            Text(glucoseState.deltaUnitText)
                .foregroundStyle(ConstantsAppColors.secondaryText)
        }
    }

    // MARK: - Sizing

    private func topRowFontSize(availableHeight: CGFloat) -> CGFloat {
        showsClock ? max(22, availableHeight * 0.10) : max(28, availableHeight * 0.15)
    }

    private func valueFontSize(availableSize: CGSize) -> CGFloat {
        min(availableSize.height * (showsClock ? 0.72 : 0.82), availableSize.width * 0.46)
    }
}
