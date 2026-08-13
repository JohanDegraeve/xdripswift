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
                ageText
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                deltaText
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .layoutPriority(1)
            }
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
                .onLongPressGesture(minimumDuration: 0.5, perform: actions.keepScreenAwake)
        }
    }

    private var ageText: Text {
        Text(state.minutesText)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(state.minutesColor)
        + Text(state.minutesAgoText.isEmpty ? "" : " \(state.minutesAgoText)")
            .font(.system(size: 20))
            .foregroundColor(ConstantsAppColors.secondaryText)
    }

    private var deltaText: Text {
        Text(state.deltaText)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(state.deltaColor)
        + Text(state.deltaUnitText.isEmpty ? "" : " \(state.deltaUnitText)")
            .font(.system(size: 20))
            .foregroundColor(ConstantsAppColors.secondaryText)
    }
}
