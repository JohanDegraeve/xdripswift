//
//  RootHomeStatisticsView.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Statistics values and time-in-range pie chart for the selected period.
struct RootHomeStatisticsView: View {
    let state: RootHomeStatisticsState
    let action: () -> Void

    private enum Layout {
        static let rowHeight: CGFloat = 80
        static let verticalPadding: CGFloat = 5
        static let pieSize: CGFloat = 48
    }

    var body: some View {
        HStack(spacing: 0) {
            RootHomeStatisticsColumn(top: state.low, bottom: state.average, limitText: state.lowLimitText)
            RootHomeStatisticsColumn(top: state.inRange, bottom: state.a1c, limitText: "")
            RootHomeStatisticsColumn(top: state.high, bottom: state.cv, limitText: state.highLimitText)

            VStack(spacing: 6) {
                ZStack {
                    RootHomePieChartView(
                        low: state.low.percentValue,
                        inRange: state.inRange.percentValue,
                        high: state.high.percentValue
                    )

                    if state.showsActivityIndicator {
                        ProgressView()
                            .tint(ConstantsAppColors.primaryText)
                    }
                }
                .frame(height: Layout.pieSize)

                Text(state.timePeriodText)
                    .font(.caption2)
                    .foregroundStyle(ConstantsAppColors.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.verticalPadding)
        .frame(height: Layout.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: action)
        .transaction { transaction in
            // Calculation updates replace label text immediately. Threshold colors animate separately.
            transaction.animation = nil
        }
    }
}

/// Vertical group of statistics with matching column alignment.
struct RootHomeStatisticsColumn: View {
    let top: RootHomeMetricState
    let bottom: RootHomeMetricState
    let limitText: String

    var body: some View {
        VStack(spacing: 10) {
            RootHomeStatisticsMetricView(metric: top, limitText: limitText)
            RootHomeStatisticsMetricView(metric: bottom)
        }
        .frame(maxWidth: .infinity)
    }
}

/// One statistics title, optional limit and calculated value.
struct RootHomeStatisticsMetricView: View {
    let metric: RootHomeMetricState
    var limitText = ""

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(metric.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ConstantsAppColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if !limitText.isEmpty {
                    Text(limitText)
                        .font(.system(size: 12))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(metric.value)
                .font(.system(size: 12))
                .foregroundStyle(metric.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// Time-in-range pie chart drawn from low, in-range and high percentages.
struct RootHomePieChartView: View {
    let low: Double
    let inRange: Double
    let high: Double

    var body: some View {
        ZStack {
            if total > 0 {
                RootHomePieSlice(startAngle: .degrees(referenceAngle), endAngle: .degrees(referenceAngle + inRangeAngle))
                    .fill(ConstantsAppColors.statisticsInRange)

                RootHomePieSlice(startAngle: .degrees(referenceAngle + inRangeAngle), endAngle: .degrees(referenceAngle + inRangeAngle + lowAngle))
                    .fill(ConstantsAppColors.statisticsLow)

                RootHomePieSlice(startAngle: .degrees(referenceAngle + inRangeAngle + lowAngle), endAngle: .degrees(referenceAngle + 360))
                    .fill(ConstantsAppColors.statisticsHigh)
            }
        }
        .frame(width: 52, height: 52)
    }
    
    private var total: Double {
        low + inRange + high
    }
    
    private var inRangeAngle: Double {
        360 * inRange / total
    }
    
    private var lowAngle: Double {
        360 * low / total
    }
    
    private var referenceAngle: Double {
        90 - (inRangeAngle / 2)
    }
}

/// One percentage slice in the Home time-in-range pie chart.
struct RootHomePieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()

        return path
    }
}

private extension RootHomeMetricState {
    var percentValue: Double {
        Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
    }
}
