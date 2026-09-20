//
//  RootHomeStatusViews.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

private enum RootHomeDisplayStyle {
    static let historicalValueOpacity = 0.7
}

private extension Bool {
    var rootHomeHistoricalValueOpacity: Double {
        self ? RootHomeDisplayStyle.historicalValueOpacity : 1
    }
}

/// Compact pump status displayed beside the current glucose reading.
struct RootHomePumpView: View {
    let state: RootHomePumpState

    static let preferredWidth: CGFloat = 158

    var body: some View {
        VStack(spacing: 0) {
            RootHomeHorizontalMetricView(metric: state.basal, valueOpacity: state.isHistorical.rootHomeHistoricalValueOpacity)
            RootHomeHorizontalMetricView(metric: state.reservoir, valueOpacity: state.isHistorical.rootHomeHistoricalValueOpacity)
            RootHomeHorizontalMetricView(metric: state.battery, valueOpacity: state.isHistorical.rootHomeHistoricalValueOpacity)
            RootHomeHorizontalMetricView(metric: state.cage, valueOpacity: state.isHistorical.rootHomeHistoricalValueOpacity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(width: Self.preferredWidth)
        .frame(maxHeight: .infinity)
        .background(panelBackground(isHistorical: state.isHistorical))
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
    }
}

/// Loop status row displayed below the pump and glucose values.
struct RootHomeLoopView: View {
    @State private var selectedMetric: Bool?
    @State private var showsMetricDetails = false
    let state: RootHomeLoopState
    let actions: RootHomeActions

    private enum Layout {
        static let statusSymbolSize: CGFloat = 18
        static let inlineMetricWidth: CGFloat = 78
        static let height: CGFloat = 34
    }

    var body: some View {
        HStack(spacing: 0) {
                if state.showsIOB {
                    metricButton(isIOB: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if state.showsCOB {
                    metricButton(isIOB: false)
                        .frame(width: Layout.inlineMetricWidth, alignment: .leading)
                }

                if state.showsAIDStatus {
                    Button(action: actions.showAIDStatus) { loopStatusView }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.height)
            .background(panelBackground(isHistorical: state.isHistorical))
            .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
        .buttonStyle(.plain)
        .sheet(isPresented: $showsMetricDetails) {
            NavigationStack {
                if let isIOB = selectedMetric, let metrics = state.therapyMetrics {
                    TherapyMetricDetailsView(metric: isIOB ? metrics.iob : metrics.cob, isIOB: isIOB)
                }
            }
        }
        .transaction { transaction in
            // Calculation updates replace label text immediately. Threshold colors animate separately.
            transaction.animation = nil
        }
        .frame(maxHeight: .infinity)
    }

    private func metricButton(isIOB: Bool) -> some View {
        let metric = isIOB ? state.therapyMetrics?.iob : state.therapyMetrics?.cob
        return Button {
            if metric?.source == .local { selectedMetric = isIOB; showsMetricDetails = true }
            else { actions.showAIDStatus() }
        } label: {
            RootHomeInlineMetricView(metric: isIOB ? state.iob : state.cob, valueOpacity: state.isHistorical.rootHomeHistoricalValueOpacity)
        }
        .accessibilityLabel(metric?.accessibilityName(isIOB: isIOB) ?? (isIOB ? "IOB" : "COB"))
        .accessibilityValue(isIOB ? state.iob.value : state.cob.value)
    }

    private var loopStatusView: some View {
        HStack(spacing: 6) {
            if state.showsUploaderBattery {
                Image(systemName: state.uploaderBatterySystemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(state.uploaderBatteryColor)
                    .opacity(state.isHistorical.rootHomeHistoricalValueOpacity)
            }

            if state.showsActivityIndicator {
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(state.isHistorical ? ConstantsAppColors.secondaryText : ConstantsAppColors.primaryText)
                    .opacity(state.isHistorical.rootHomeHistoricalValueOpacity)
            }

            if state.showsStatusTimeAgo {
                Text(state.statusTimeAgo)
                    .font(.system(size: 16))
                    .foregroundStyle(state.isHistorical ? ConstantsAppColors.secondaryText : ConstantsAppColors.primaryText)
                    .opacity(state.isHistorical.rootHomeHistoricalValueOpacity)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            if let statusSymbol = state.statusSymbol {
                AIDStatusSymbolImage(symbol: statusSymbol)
                    .font(.system(size: Layout.statusSymbolSize, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(state.statusColor)
                    .opacity(state.isHistorical.rootHomeHistoricalValueOpacity)
            }
        }
    }
}

private func panelBackground(isHistorical: Bool) -> Color {
    ConstantsAppColors.homePanelBackground.opacity(isHistorical ? 0.3 : 1)
}

/// One compact title and value pair used inside the pump panel.
struct RootHomeInlineMetricView: View {
    let metric: RootHomeMetricState
    var valueOpacity = 1.0

    var body: some View {
        HStack(spacing: 6) {
            Text(metric.title)
                .font(.system(size: 16))
                .foregroundStyle(ConstantsAppColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(metric.value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(metric.valueColor)
                .opacity(valueOpacity)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

/// One horizontal title and value pair used by the loop row.
struct RootHomeHorizontalMetricView: View {
    let metric: RootHomeMetricState
    var valueOpacity = 1.0

    var body: some View {
        HStack(spacing: 4) {
            Text(metric.title)
                .font(.system(size: 15))
                .foregroundStyle(ConstantsAppColors.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(metric.value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(metric.valueColor)
                .opacity(valueOpacity)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxHeight: .infinity)
    }
}
