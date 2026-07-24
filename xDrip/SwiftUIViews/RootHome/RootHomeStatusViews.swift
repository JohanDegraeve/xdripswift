//
//  RootHomeStatusViews.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Compact pump status displayed beside the current glucose reading.
struct RootHomePumpView: View {
    let state: RootHomePumpState

    private enum Layout {
        static let width: CGFloat = 158
    }

    var body: some View {
        VStack(spacing: 0) {
            RootHomeHorizontalMetricView(metric: state.basal)
            RootHomeHorizontalMetricView(metric: state.reservoir)
            RootHomeHorizontalMetricView(metric: state.battery)
            RootHomeHorizontalMetricView(metric: state.cage)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(width: Layout.width)
        .frame(maxHeight: .infinity)
        .background(ConstantsAppColors.homePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
    }
}

/// Loop status row displayed below the pump and glucose values.
struct RootHomeLoopView: View {
    let state: RootHomeLoopState
    let actions: RootHomeActions

    private enum Layout {
        static let statusSymbolSize: CGFloat = 18
    }

    var body: some View {
        Button(action: actions.showAIDStatus) {
            HStack(spacing: 0) {
                RootHomeInlineMetricView(metric: state.iob)
                Spacer(minLength: 16)
                RootHomeInlineMetricView(metric: state.cob)
                Spacer(minLength: 16)

                HStack(spacing: 6) {
                    if state.showsUploaderBattery {
                        Image(systemName: state.uploaderBatterySystemImage)
                            .font(.system(size: 14))
                            .foregroundStyle(state.uploaderBatteryColor)
                    }

                    if state.showsActivityIndicator {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(ConstantsAppColors.primaryText)
                    }

                    if let statusSystemImage = state.statusSystemImage {
                        Image(systemName: statusSystemImage)
                            .font(.system(size: Layout.statusSymbolSize, weight: .black))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(state.statusColor)
                    }

                    Text(state.statusTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(state.statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    if state.showsStatusTimeAgo {
                        Text(state.statusTimeAgo)
                            .font(.system(size: 16))
                            .foregroundStyle(ConstantsAppColors.primaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(ConstantsAppColors.homePanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            // Calculation updates replace label text immediately. Threshold colors animate separately.
            transaction.animation = nil
        }
        .frame(maxHeight: .infinity)
    }
}

/// One compact title and value pair used inside the pump panel.
struct RootHomeInlineMetricView: View {
    let metric: RootHomeMetricState

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
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

/// One horizontal title and value pair used by the loop row.
struct RootHomeHorizontalMetricView: View {
    let metric: RootHomeMetricState

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
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxHeight: .infinity)
    }
}
