//
//  RootHomeSelectorView.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Quiet, direct controls for the statistics calculation period and main-chart width.
struct RootHomeSelectorView: View {
    @Binding var selectedRange: RootHomeChartRange
    let statisticsDays: Int
    let showsStatistics: Bool
    let onStatisticsDaysChanged: (Int) -> Void

    private let statisticsOptions = [0, 1, 7, 30, 90]

    private enum Layout {
        static let controlHeight: CGFloat = 30
    }

    var body: some View {
        HStack(spacing: 4) {
            if showsStatistics {
                HStack(spacing: 2) {
                    ForEach(statisticsOptions, id: \.self) { days in
                        RootHomeSelectorButton(
                            title: statisticsTitle(for: days),
                            accessibilityLabel: Texts_SettingsView.labelDaysToUseStatisticsTitle,
                            accessibilityValue: statisticsAccessibilityValue(for: days),
                            indicatorDirection: .down,
                            isSelected: statisticsDays == days,
                            action: { onStatisticsDaysChanged(days) }
                        )
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear
                    .frame(width: 9, height: 14)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 2) {
                ForEach(RootHomeChartRange.allCases) { range in
                    RootHomeSelectorButton(
                        title: range.title,
                        accessibilityLabel: Texts_HomeView.showHideGlucoseChartTitle,
                        accessibilityValue: "\(Int(range.rawValue)) \(Texts_Common.hours)",
                        indicatorDirection: .up,
                        isSelected: selectedRange == range,
                        action: { selectedRange = range }
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: showsStatistics ? .trailing : .center)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: Layout.controlHeight)
    }

    private func statisticsTitle(for days: Int) -> String {
        RootHomeStatisticsPeriodText.title(for: days)
    }

    private func statisticsAccessibilityValue(for days: Int) -> String {
        switch days {
        case 0:
            return Texts_Common.today
        case 1:
            return "1 \(Texts_Common.day)"
        default:
            return "\(days) \(Texts_Common.days)"
        }
    }
}

/// One label-only selector item. Its indicator points toward the content controlled by the group.
struct RootHomeSelectorButton: View {
    let title: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let indicatorDirection: RootHomeSelectorIndicator.Direction
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ConstantsAppColors.primaryText : ConstantsAppColors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .frame(minWidth: 32, maxHeight: .infinity)
                .overlay(alignment: indicatorDirection == .up ? .top : .bottom) {
                    RootHomeSelectorIndicator(direction: indicatorDirection)
                        .fill(ConstantsGlucoseChartSwiftUI.overlayWindowEdgeColor)
                        .frame(width: 16, height: 6)
                        .opacity(isSelected ? 1 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A shallow directional marker linking a selector group to the content above or below it.
struct RootHomeSelectorIndicator: Shape {
    enum Direction {
        case up
        case down
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}
