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

    private enum Layout {
        static let buttonSize: CGFloat = 38
        static let iconSize: CGFloat = 23
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 3
    }

    @State private var originalGlucosePeekIsActive = false
    @State private var shouldIgnoreNextPostProcessingTap = false

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton(systemImage: state.controls.snoozeSystemImage, label: Texts_HomeView.snoozeButton, action: actions.showSnooze)
                .contextMenu {
                    ForEach(Array(SensorHealthTestKind.allCases.enumerated()), id: \.offset) { _, testKind in
                        Button(testKind.testMenuTitle) {
                            actions.queueSensorHealthTest(testKind)
                        }
                    }
                }
            toolbarButton(systemImage: "drop", label: "BgReadings", action: actions.showBgReadings)
            sensorToolbarButton()
            postProcessingToolbarButton()
            toolbarButton(systemImage: "rectangle.3.group", label: "Show/Hide", action: actions.showHideItems)
            screenLockToolbarButton()
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxWidth: .infinity)
    }

    private func sensorToolbarButton() -> some View {
        let isEnabled = state.controls.sensorButtonEnabled

        return Image(systemName: "sensor.tag.radiowaves.forward")
            .font(.system(size: Layout.iconSize, weight: .regular))
            .frame(width: Layout.buttonSize, height: Layout.buttonSize)
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.35)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        guard isEnabled else { return }

                        switch result {
                        case .first:
                            actions.toolbarLongPressActivated()
                            actions.showCalibration()
                        case .second:
                            actions.showSensorManagement()
                        }
                    }
            )
            .foregroundStyle(ConstantsAppColors.toolbarIcon)
            .frame(maxWidth: .infinity)
            .opacity(isEnabled ? 1 : 0.35)
            .allowsHitTesting(isEnabled)
            .accessibilityElement()
            .accessibilityLabel(Texts_HomeView.sensor)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                actions.showSensorManagement()
            }
            .accessibilityAction(named: Text(Texts_HomeView.calibrationButton)) {
                actions.showCalibration()
            }
    }

    private func postProcessingToolbarButton() -> some View {
        Image(systemName: state.controls.postProcessingSystemImage)
            .font(.system(size: Layout.iconSize, weight: .regular))
            .frame(width: Layout.buttonSize, height: Layout.buttonSize)
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
                actions.toolbarLongPressActivated()
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

    /// A tap toggles the full Clock Mode layout. A long press enables the existing silent
    /// keep-awake lock without also firing the tap action when the gesture completes.
    private func screenLockToolbarButton() -> some View {
        Image(systemName: state.isScreenLocked ? "lock.fill" : "lock")
            .font(.system(size: Layout.iconSize, weight: .regular))
            .frame(width: Layout.buttonSize, height: Layout.buttonSize)
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first:
                            actions.keepScreenAwake()
                        case .second:
                            actions.toggleScreenLock()
                        }
                    }
            )
            .foregroundStyle(
                state.isScreenLocked && !state.usesScreenLockNightLayout
                    ? ConstantsAppColors.toolbarLockedIcon
                    : ConstantsAppColors.toolbarIcon
            )
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel(state.isScreenLocked ? Texts_HomeView.unlockButton : Texts_HomeView.lockButton)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                actions.toggleScreenLock()
            }
    }

    private func toolbarButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Layout.iconSize, weight: .regular))
                .frame(width: Layout.buttonSize, height: Layout.buttonSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ConstantsAppColors.toolbarIcon)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}
