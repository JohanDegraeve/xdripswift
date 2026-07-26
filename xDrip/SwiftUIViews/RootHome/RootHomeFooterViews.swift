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

/// Sensor lifetime progress indicator.
struct RootHomeSensorLifetimeView: View {
    let state: RootHomeSensorState

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(UserDefaults.Key.preferSensorCountdown.rawValue) private var preferSensorCountdown = false
    @State private var displayedProgress: Double
    @State private var progressAnimationTask: Task<Void, Never>?
    @State private var isVisible = false
    @State private var isEntranceAnimationInProgress = false
    @State private var pendingProgress: Double?

    private enum Layout {
        static let height: CGFloat = 10
    }

    /// keeps the progress and its direction in the same SwiftUI update
    private struct ProgressState: Equatable {
        let progress: Double
        let countsDown: Bool
    }

    init(state: RootHomeSensorState) {
        self.state = state
        _displayedProgress = State(initialValue: UserDefaults.standard.preferSensorCountdown ? 1 : 0)
    }

    var body: some View {
        ProgressView(value: displayedProgress)
            .progressViewStyle(.linear)
            .tint(state.progressColor)
            .frame(height: 5)
            .frame(maxHeight: .infinity, alignment: .center)
            .frame(height: Layout.height)
            .onAppear {
                isVisible = true
                startEntranceAnimation()
            }
            .onDisappear {
                isVisible = false
                prepareProgressForNextEntrance()
            }
            .onChange(of: preferSensorCountdown) { _ in
                if isVisible, scenePhase == .active {
                    startEntranceAnimation()
                } else {
                    resetProgressToEndpoint()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active, isVisible {
                    // root home is not necessarily recreated when returning
                    // through the app icon or Dynamic Island
                    startEntranceAnimation()
                } else {
                    // reset while the scene is still becoming inactive, before
                    // iOS snapshots and suspends the view for the background
                    prepareProgressForNextEntrance()
                }
            }
            .onChange(of: progressState) { newState in
                guard isVisible, scenePhase == .active else {
                    resetProgressToEndpoint()
                    return
                }

                // keep the latest complete progress/direction pair until the
                // entrance animation has finished
                if isEntranceAnimationInProgress {
                    pendingProgress = presentationProgress(newState)
                    return
                }

                displayedProgress = presentationProgress(newState)
            }
    }

    private var progressState: ProgressState {
        ProgressState(progress: state.progress, countsDown: state.countsDown)
    }

    private func startEntranceAnimation() {
        prepareProgressForNextEntrance()
        isEntranceAnimationInProgress = true

        let targetProgress = presentationProgress(progressState)

        progressAnimationTask = Task { @MainActor in
            // allow SwiftUI to render the directional 0% or 100% starting state
            // before beginning the progress animation
            await Task.yield()

            guard !Task.isCancelled else { return }

            let currentTargetProgress = pendingProgress ?? targetProgress
            pendingProgress = nil

            withAnimation(.easeOut(duration: ConstantsHomeView.sensorProgressEntranceAnimationDuration)) {
                displayedProgress = currentTargetProgress
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(ConstantsHomeView.sensorProgressEntranceAnimationDuration * 1_000_000_000))
            } catch {
                return
            }

            isEntranceAnimationInProgress = false

            if let pendingProgress {
                displayedProgress = pendingProgress
                self.pendingProgress = nil
            }
        }
    }

    /// cancels the current animation and leaves the progress ready for its next entrance
    private func prepareProgressForNextEntrance() {
        progressAnimationTask?.cancel()
        isEntranceAnimationInProgress = false
        pendingProgress = nil
        resetProgressToEndpoint()
    }

    /// resets to 0% for elapsed mode or 100% for countdown mode without animation
    private func resetProgressToEndpoint() {
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true

        withTransaction(resetTransaction) {
            displayedProgress = preferSensorCountdown ? 1 : 0
        }
    }

    /// converts a progress value created with stale state into the user's current
    /// elapsed/countdown preference while root home refreshes after a tab change
    private func presentationProgress(_ state: ProgressState) -> Double {
        let progress = clampedProgress(state.progress)
        return state.countsDown == preferSensorCountdown ? progress : 1 - progress
    }

    private func clampedProgress(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
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
