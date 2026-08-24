//
//  LandscapeValueView.swift
//  xdrip
//
//  Created by Johan Degraeve on 24/12/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Purpose-built iPhone landscape presentation used by full Clock Mode.
///
/// Glucose remains the primary readout, while the optional clock receives enough width to be read
/// at a distance. The compact status line preserves applicable Loop, AID and CareLink state without
/// bringing the dense portrait Home hierarchy into the short landscape canvas.
struct LandscapeValueView: View {

    let state: RootHomeState

    private enum Layout {
        static let glucoseWidthFraction = 0.58
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 12
        static let readoutColumnSpacing: CGFloat = 40
        static let readoutStatusSpacing: CGFloat = 12
        static let statusRowHeight: CGFloat = 64
        static let statusRowColumnSpacing: CGFloat = 16
        static let statusSpacing: CGFloat = 8
        static let statusFontSize: CGFloat = 30
        static let statusSymbolSize: CGFloat = 32
        static let readoutFontSize: CGFloat = 500
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(geometry.size.width - (Layout.horizontalPadding * 2), 0)
            let columnSpacing = state.visibility.showsClock
                ? Layout.readoutColumnSpacing
                : 0
            let availableReadoutWidth = max(contentWidth - columnSpacing, 0)

            VStack(spacing: Layout.readoutStatusSpacing) {
                HStack(spacing: Layout.readoutColumnSpacing) {
                    glucoseView
                        .frame(
                            width: state.visibility.showsClock
                                ? availableReadoutWidth * Layout.glucoseWidthFraction
                                : availableReadoutWidth
                        )

                    if state.visibility.showsClock {
                        clockView
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)

                statusRow
                    .frame(height: Layout.statusRowHeight)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .colorScheme(.dark)
    }

    private var glucoseView: some View {
        Text(state.glucose.valueText)
            .font(.system(size: Layout.readoutFontSize, weight: .bold))
            .foregroundStyle(state.glucose.valueColor)
            .strikethrough(
                state.glucose.valueHasStrikethrough,
                color: state.glucose.valueColor
            )
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.01)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clockView: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(context.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: Layout.readoutFontSize, weight: .bold))
                .foregroundStyle(ConstantsAppColors.clockText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusRow: some View {
        HStack(spacing: Layout.statusRowColumnSpacing) {
            minutesView
                .frame(maxWidth: .infinity)

            deltaView
                .frame(maxWidth: .infinity)

            Group {
                if showsTherapyStatus {
                    therapyStatusView
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .font(.system(size: Layout.statusFontSize, weight: .medium))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .allowsTightening(true)
    }

    private var minutesView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(state.glucose.minutesText)
                .foregroundStyle(state.glucose.minutesColor)
                .monospacedDigit()

            Text(state.glucose.minutesAgoText)
                .foregroundStyle(ConstantsAppColors.secondaryText)
        }
    }

    private var deltaView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(state.glucose.deltaText)
                .foregroundStyle(state.glucose.deltaColor)
                .monospacedDigit()

            Text(state.glucose.deltaUnitText)
                .foregroundStyle(ConstantsAppColors.secondaryText)
        }
    }

    private var therapyStatusView: some View {
        HStack(spacing: Layout.statusSpacing) {
            if state.loop.showsActivityIndicator {
                ProgressView()
                    .scaleEffect(0.85)
                    .tint(ConstantsAppColors.primaryText)
                    .frame(width: Layout.statusSymbolSize, height: Layout.statusSymbolSize)
            } else if let statusSystemImage = state.loop.statusSystemImage {
                Image(systemName: statusSystemImage)
                    .font(.system(size: Layout.statusSymbolSize, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(state.loop.statusColor)
            }

            Text(state.loop.statusTitle)
                .foregroundStyle(ConstantsAppColors.primaryText)

            if state.loop.showsStatusTimeAgo, !state.loop.statusTimeAgo.isEmpty {
                Text(state.loop.statusTimeAgo)
                    .foregroundStyle(ConstantsAppColors.secondaryText)
                    .monospacedDigit()
            }
        }
    }

    private var showsTherapyStatus: Bool {
        state.loop.showsActivityIndicator || state.loop.statusSystemImage != nil
    }
}
