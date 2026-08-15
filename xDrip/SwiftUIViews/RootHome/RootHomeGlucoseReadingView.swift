//
//  RootHomeGlucoseReadingView.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Current glucose value, age and delta presentation.
struct RootHomeGlucoseReadingView: View {
    let state: RootHomeGlucoseState
    let isScreenLocked: Bool
    let nightLockStatus: RootHomeLoopState?

    private enum Layout {
        static let infoHorizontalPadding: CGFloat = 8
        static let normalInfoFontSize: CGFloat = 20
        static let nightLockInfoFontSize: CGFloat = 26
        static let nightLockStatusSymbolSize: CGFloat = 24
        static let normalValueFontSize: CGFloat = 78
        // Start deliberately large so minimumScaleFactor fits every value to the available width.
        static let nightLockValueFontSize: CGFloat = 500
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ageText
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    deltaText
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)

                    nightLockStatusIndicator
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, Layout.infoHorizontalPadding)

            Text(state.valueText)
                .font(.system(
                    size: isScreenLocked ? Layout.nightLockValueFontSize : Layout.normalValueFontSize,
                    weight: isScreenLocked ? .bold : .medium
                ))
                .foregroundStyle(state.valueColor)
                .strikethrough(state.valueHasStrikethrough, color: state.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(isScreenLocked ? 0.01 : 0.2)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var nightLockStatusIndicator: some View {
        if isScreenLocked, let nightLockStatus {
            if let statusSystemImage = nightLockStatus.statusSystemImage {
                Image(systemName: statusSystemImage)
                    .font(.system(size: Layout.nightLockStatusSymbolSize, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(nightLockStatus.statusColor)
            } else if nightLockStatus.showsActivityIndicator {
                ProgressView()
                    .scaleEffect(0.85)
                    .tint(ConstantsAppColors.primaryText)
                    .frame(width: Layout.nightLockStatusSymbolSize, height: Layout.nightLockStatusSymbolSize)
            }
        }
    }

    private var infoFontSize: CGFloat {
        isScreenLocked ? Layout.nightLockInfoFontSize : Layout.normalInfoFontSize
    }

    private var ageText: Text {
        Text(state.minutesText)
            .font(.system(size: infoFontSize, weight: .medium))
            .foregroundColor(state.minutesColor)
        + Text(state.minutesAgoText.isEmpty ? "" : " \(state.minutesAgoText)")
            .font(.system(size: infoFontSize))
            .foregroundColor(ConstantsAppColors.secondaryText)
    }

    private var deltaText: Text {
        Text(state.deltaText)
            .font(.system(size: infoFontSize, weight: .medium))
            .foregroundColor(state.deltaColor)
        + Text(state.deltaUnitText.isEmpty ? "" : " \(state.deltaUnitText)")
            .font(.system(size: infoFontSize))
            .foregroundColor(ConstantsAppColors.secondaryText)
    }
}
