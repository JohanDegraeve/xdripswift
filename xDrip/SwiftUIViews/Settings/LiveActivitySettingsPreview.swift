//
//  LiveActivitySettingsPreview.swift
//  xdrip
//
//  Created by Paul Plant on 3/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Shows the selected Live Activity layout with current data or representative fallback data.
struct LiveActivitySettingsPreview: View {
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    @AppStorage(UserDefaults.Key.liveActivityType.rawValue)
    private var liveActivityTypeRawValue = LiveActivityType.disabled.rawValue
    @AppStorage(UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue) private var isMgDl = true

    private var liveActivityType: LiveActivityType {
        LiveActivityType(rawValue: liveActivityTypeRawValue) ?? .disabled
    }

    private var previewState: XDripWidgetAttributes.ContentState {
        var state = liveActivityManager.contentStateForPreview ?? makePlaceholderState(
            liveActivityType: liveActivityType,
            carPlayLiveActivityType: .chart,
            isMgDl: isMgDl
        )
        state.liveActivityType = liveActivityType
        state.warnUserToOpenApp = false
        return state
    }

    private var liveActivityPreviewHeight: CGFloat {
        switch liveActivityType {
        case .minimal:
            return 78
        case .normal:
            return 104
        case .large:
            return 166
        case .disabled:
            return 0
        }
    }

    var body: some View {
        if liveActivityType != .disabled {
            LiveActivityViewContentState(state: previewState)
                .frame(maxWidth: .infinity)
                .frame(height: liveActivityPreviewHeight)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accessibilityElement(children: .contain)
        }
    }
}

/// Shows the selected CarPlay layout for the small supplemental Live Activity family.
/// Apple Watch also uses this family.
struct CarPlayLiveActivitySettingsPreview: View {
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    @AppStorage(UserDefaults.Key.liveActivityType.rawValue)
    private var liveActivityTypeRawValue = LiveActivityType.disabled.rawValue
    @AppStorage(UserDefaults.Key.carPlayLiveActivityType.rawValue)
    private var carPlayLiveActivityTypeRawValue = CarPlayLiveActivityType.chart.rawValue
    @AppStorage(UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue) private var isMgDl = true

    private var liveActivityType: LiveActivityType {
        LiveActivityType(rawValue: liveActivityTypeRawValue) ?? .disabled
    }

    private var carPlayLiveActivityType: CarPlayLiveActivityType {
        CarPlayLiveActivityType(rawValue: carPlayLiveActivityTypeRawValue) ?? .chart
    }

    private var previewState: XDripWidgetAttributes.ContentState {
        var state = liveActivityManager.contentStateForPreview ?? makePlaceholderState(
            liveActivityType: liveActivityType,
            carPlayLiveActivityType: carPlayLiveActivityType,
            isMgDl: isMgDl
        )
        state.carPlayLiveActivityType = carPlayLiveActivityType
        state.warnUserToOpenApp = false
        return state
    }

    var body: some View {
        if #available(iOS 26.0, *), liveActivityType != .disabled {
            LiveActivityViewContentActivityFamiliesState(state: previewState)
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.vertical, 10)
                .accessibilityElement(children: .contain)
        }
    }
}

/// Keeps both previews useful before the first real Live Activity state has been prepared.
private func makePlaceholderState(
    liveActivityType: LiveActivityType,
    carPlayLiveActivityType: CarPlayLiveActivityType,
    isMgDl: Bool
) -> XDripWidgetAttributes.ContentState {
    let readingCount = 97
    let dates = (0 ..< readingCount).map { Date().addingTimeInterval(-Double($0 * 5 * 60)) }
    let values: [Double] = (0 ..< readingCount).map { index -> Double in
        let position = Double(index)
        return 123 + sin(position / 8) * 22 + cos(position / 19) * 12
    }

    return XDripWidgetAttributes.ContentState(
        bgReadingValues: values,
        bgReadingDates: dates,
        isMgDl: isMgDl,
        slopeOrdinal: 4,
        deltaValueInUserUnit: isMgDl ? 3 : 0.2,
        urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue,
        lowLimitInMgDl: UserDefaults.standard.lowMarkValue,
        highLimitInMgDl: UserDefaults.standard.highMarkValue,
        urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue,
        liveActivityType: liveActivityType,
        carPlayLiveActivityType: carPlayLiveActivityType,
        dataSourceDescription: "Libre 2",
        sensorNoiseStateRawValue: Int(SensorNoiseState.low.rawValue),
        aidStatus: AIDStatus(condition: .active, style: .loop, statusUpdatedAt: .now, lastActivityAt: .now, iob: 1.25, cob: 12, statusTitle: "Looping", staleStatusTitle: "No data")
    )
}
