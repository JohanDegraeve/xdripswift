//
//  RootHomeFooterViews.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Tappable home warning that opens the persisted sensor-noise details.
struct RootHomeSensorNoiseWarningView: View {
    let state: RootHomeSensorNoiseState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ConstantsAppColors.warning)

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ConstantsAppColors.primaryText)
                    Text(state.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ConstantsAppColors.secondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(state.color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous)
                    .stroke(state.color.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Sensor age and directional lifetime progress indicator.
struct RootHomeSensorLifetimeView: View {
    let state: RootHomeSensorState

    private enum Layout {
        static let height: CGFloat = 10
    }

    var body: some View {
        GeometryReader { geometry in
            let progress = min(max(state.progress, 0), 1)
            let arrowPosition = min(max(progress * geometry.size.width, 7), geometry.size.width - 7)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(state.progressColor)
                .frame(height: 5)
                .overlay {
                    Image(systemName: state.countsDown ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .scaleEffect(x: 0.75, y: 0.95)
                        .foregroundStyle(state.progressColor)
                        .opacity(0.85)
                        .position(x: arrowPosition, y: 2.5)
                }
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: Layout.height)
    }
}

/// Active data source, connection state and follower keep-alive status.
struct RootHomeDataSourceView: View {
    let state: RootHomeDataSourceState
    let sensorState: RootHomeSensorState
    let sensorNoiseState: RootHomeSensorNoiseState
    let action: () -> Void

    private enum Layout {
        static let height: CGFloat = 30
    }

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 6) {
                if sensorNoiseState.showsIndicator {
                    Circle()
                        .fill(sensorNoiseState.indicatorColor)
                        .frame(width: 8, height: 8)
                        .overlay {
                            Circle()
                                .stroke(sensorNoiseState.indicatorColor.opacity(0.35), lineWidth: 3)
                        }
                        .accessibilityLabel(sensorNoiseState.indicatorAccessibilityLabel)
                }

                if state.showsConnectionIcon {
                    Circle()
                        .fill(state.connectionColor)
                        .frame(width: 8, height: 8)
                }
                
                if state.showsKeepAliveIcon {
                    Image(systemName: state.keepAliveSystemImage)
                        .font(.system(size: 15))
                        .foregroundStyle(state.keepAliveColor)
                }

                Text(state.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ConstantsAppColors.dataSourceText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                Text(dataSourceDetailText)
                    .font(.system(size: 14))
                    .foregroundStyle(dataSourceDetailColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let maxAgeText {
                    Text(maxAgeText)
                        .font(.system(size: 14))
                        .foregroundStyle(ConstantsAppColors.dataSourceText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Layout.height)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: action)
    }

    private var dataSourceDetailText: String {
        sensorState.currentAge.isEmpty ? state.detail : sensorState.currentAge
    }

    private var maxAgeText: String? {
        sensorState.currentAge.isEmpty || sensorState.maxAge.isEmpty || sensorState.countsDown ? nil : sensorState.maxAge
    }

    private var dataSourceDetailColor: Color {
        sensorState.currentAge.isEmpty ? state.detailColor : sensorState.currentAgeColor
    }
}
