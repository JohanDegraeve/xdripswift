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
    let actions: RootHomeActions

    private enum Layout {
        static let infoHorizontalPadding: CGFloat = 8
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 4) {
                    Text(state.minutesText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(state.minutesColor)
                        .monospacedDigit()

                    Text(state.minutesAgoText)
                        .font(.system(size: 20))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text(state.deltaText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(state.deltaColor)
                        .monospacedDigit()

                    Text(state.deltaUnitText)
                        .font(.system(size: 20))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .padding(.horizontal, Layout.infoHorizontalPadding)

            Text(state.valueText)
                .font(.system(size: isScreenLocked ? 120 : 78, weight: .medium))
                .foregroundStyle(state.valueColor)
                .strikethrough(state.valueHasStrikethrough, color: state.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .onTapGesture(perform: actions.toggleExpandedAIDInfo)
                .onLongPressGesture(minimumDuration: 0.5, perform: actions.keepScreenAwake)
        }
    }
}
