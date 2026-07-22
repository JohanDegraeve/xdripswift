//
//  RootHomeToolbarView.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Home toolbar with commands supplied by the tab and application coordinator.
struct RootHomeToolbarView: View {
    let state: RootHomeState
    let actions: RootHomeActions
    let beginOriginalGlucosePeek: () -> Void
    let endOriginalGlucosePeek: () -> Void

    @State private var originalGlucosePeekIsActive = false
    @State private var shouldIgnoreNextPostProcessingTap = false

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton(systemImage: state.controls.snoozeSystemImage, label: Texts_HomeView.snoozeButton, action: actions.showSnooze)
            toolbarButton(systemImage: "drop", label: "BgReadings", action: actions.showBgReadings)
            toolbarButton(systemImage: "sensor.tag.radiowaves.forward", label: Texts_HomeView.sensor, action: actions.showSensorManagement)
                .disabled(!state.controls.sensorButtonEnabled)
                .opacity(state.controls.sensorButtonEnabled ? 1 : 0.35)
            postProcessingToolbarButton()
            toolbarButton(systemImage: "rectangle.3.group", label: "Show/Hide", action: actions.showHideItems)
            toolbarButton(systemImage: state.isScreenLocked ? "lock.fill" : "lock", label: Texts_HomeView.lockButton, action: actions.toggleScreenLock)
                .foregroundStyle(state.isScreenLocked ? ConstantsAppColors.toolbarLockedIcon : ConstantsAppColors.toolbarIcon)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: RootHomeLayout.toolbarMinimumHeight)
    }

    private func postProcessingToolbarButton() -> some View {
        Image(systemName: state.controls.postProcessingSystemImage)
            .font(.system(size: 23, weight: .regular))
            .frame(width: 38, height: 38)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !shouldIgnoreNextPostProcessingTap else {
                    shouldIgnoreNextPostProcessingTap = false
                    return
                }

                actions.showBgAdjustments()
            }
            .simultaneousGesture(originalGlucosePeekGesture())
            .foregroundStyle(ConstantsAppColors.toolbarIcon)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Texts_HomeView.postProcessingTitle)
    }

    private func originalGlucosePeekGesture() -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, _) = value else { return }
                guard state.controls.postProcessingEnabled, !originalGlucosePeekIsActive else { return }

                originalGlucosePeekIsActive = true
                shouldIgnoreNextPostProcessingTap = true
                actions.originalGlucosePeekActivated()
                beginOriginalGlucosePeek()
            }
            .onEnded { _ in
                guard originalGlucosePeekIsActive else { return }

                originalGlucosePeekIsActive = false
                endOriginalGlucosePeek()

                // Do not let release of a completed peek also open the adjustments screen. Clear the
                // guard shortly afterwards if no tap event consumed it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    shouldIgnoreNextPostProcessingTap = false
                }
            }
    }

    private func toolbarButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 23, weight: .regular))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ConstantsAppColors.toolbarIcon)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}
