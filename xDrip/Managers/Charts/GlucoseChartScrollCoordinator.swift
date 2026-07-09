//
//  GlucoseChartScrollCoordinator.swift
//  xdrip
//
//  Created by Paul Plant on 9/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// Owns the visible date window and drag/deceleration behaviour for a glucose chart.
///
/// This class deliberately does not load chart data or render marks. Callers observe `endDate`,
/// derive `startDate`, and ask `GlucoseChartStateManager` to fill any missing cached data.
///
/// This separation matches the useful architecture of the UIKit chart: gesture handling changes the
/// visible time window, and the data manager responds by extending/cleaning its local cache. Keeping
/// this coordinator free of Core Data and chart marks lets the same behaviour be reused by the home
/// chart, debug chart, watch chart or any future SwiftUI chart surface.
final class GlucoseChartScrollCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var endDate: Date

    // MARK: - Configuration

    private(set) var visibleTimeInterval: TimeInterval

    // MARK: - Drag and Deceleration State

    /// Drag tracking is stored in points, then converted to seconds using the current chart width.
    ///
    /// The UIKit manager used `diffInSecondsBetweenTwoPoints` from the inner frame width. This is
    /// the same model expressed without depending on the old `BloodGlucoseChartView` frame.
    private var dragStartEndDate: Date?
    private var dragLastTranslationWidth: CGFloat?
    private var dragLastUpdateDate: Date?
    private var dragVelocityWidth: CGFloat = 0
    private var decelerationTimer: Timer?

    private static let minimumDecelerationVelocityWidth: CGFloat = 20
    private static let minimumDecelerationDistanceWidth: CGFloat = 1
    private static let minimumPublishDistanceWidth: CGFloat = 1
    private static let maximumReleaseVelocityWidth: CGFloat = 6_000
    /// SwiftUI's predicted drag velocity is a little more conservative than the old
    /// `UIPanGestureRecognizer.velocity(in:)`, so we apply a small multiplier to keep fast swipes
    /// feeling close to the UIKit chart without changing the state manager or renderer.
    private static let releaseVelocityMultiplier: CGFloat = 1.3
    /// The old chart uses `UIScrollView.DecelerationRate.normal`. The tiny boost here gives the new
    /// chart a little more carry after a fast release while still using the same exponential formula.
    private static let decelerationRateBoost = 0.00035
    private static let maximumDecelerationRate = 0.999

    // MARK: - Initialisation

    /// - Parameters:
    ///   - endDate: Initial visible end date. Defaults to now.
    ///   - visibleTimeInterval: Visible chart duration in seconds. Negative values are accepted and normalized.
    init(endDate: Date = Date(), visibleTimeInterval: TimeInterval) {
        self.endDate = endDate
        self.visibleTimeInterval = abs(visibleTimeInterval)
    }

    // MARK: - Visible Window

    var startDate: Date {
        endDate.addingTimeInterval(-visibleTimeInterval)
    }

    var isShowingCurrentTimeRange: Bool {
        endDate.timeIntervalSinceNow > -60
    }

    /// Updates the visible duration while preserving the current end date.
    func setVisibleTimeInterval(_ visibleTimeInterval: TimeInterval) {
        stopDeceleration()
        self.visibleTimeInterval = abs(visibleTimeInterval)
    }

    /// Returns the visible window to now and stops any in-flight drag/deceleration state.
    func resetToNow() {
        stopDeceleration()
        publishEndDate(Date(), force: true)
        dragStartEndDate = nil
        resetDragTracking()
    }

    /// Refreshes the end date only while the chart is already showing the current range.
    @discardableResult func refreshCurrentTimeRangeIfNeeded() -> Bool {
        guard isShowingCurrentTimeRange else { return false }

        publishEndDate(Date(), force: true)

        return true
    }

    // MARK: - Drag Handling

    func updateVisibleRange(value: DragGesture.Value, chartWidth: CGFloat) {
        // Same behaviour as the old long-press/pan combination: the moment the user touches and
        // starts another drag, any in-flight deceleration must stop immediately.
        stopDeceleration()
        updateDragVelocity(translationWidth: value.translation.width, date: value.time)
        updateVisibleRange(translationWidth: value.translation.width, chartWidth: chartWidth, forcePublish: false)
    }

    /// Applies the final drag translation and starts inertia from the measured drag velocity.
    func finishUpdatingVisibleRange(value: DragGesture.Value, chartWidth: CGFloat) {
        updateDragVelocity(translationWidth: value.translation.width, date: value.time)
        updateVisibleRange(translationWidth: value.translation.width, chartWidth: chartWidth, forcePublish: true)
        dragStartEndDate = nil

        let velocityWidth = releaseVelocityWidth(for: value)

        resetDragTracking()
        startDeceleration(velocityWidth: velocityWidth, chartWidth: chartWidth)
    }

    // MARK: - Deceleration

    func stopDeceleration() {
        decelerationTimer?.invalidate()
        decelerationTimer = nil
    }

    // MARK: - Private Helpers

    private func updateVisibleRange(translationWidth: CGFloat, chartWidth: CGFloat, forcePublish: Bool) {
        let baseEndDate = dragStartEndDate ?? endDate
        let secondsPerPoint = visibleTimeInterval / max(Double(chartWidth), 1)
        let proposedEndDate = baseEndDate.addingTimeInterval(-Double(translationWidth) * secondsPerPoint)
        let clampedEndDate = min(proposedEndDate, Date())

        dragStartEndDate = baseEndDate
        publishEndDate(clampedEndDate, minimumTimeInterval: secondsPerPoint * Double(Self.minimumPublishDistanceWidth), force: forcePublish)
    }

    private func updateDragVelocity(translationWidth: CGFloat, date: Date) {
        if let dragLastTranslationWidth = dragLastTranslationWidth, let dragLastUpdateDate = dragLastUpdateDate {
            let elapsedTime = date.timeIntervalSince(dragLastUpdateDate)

            if elapsedTime > 0 {
                dragVelocityWidth = (translationWidth - dragLastTranslationWidth) / CGFloat(elapsedTime)
            }
        }

        dragLastTranslationWidth = translationWidth
        dragLastUpdateDate = date
    }

    private func resetDragTracking() {
        dragLastTranslationWidth = nil
        dragLastUpdateDate = nil
        dragVelocityWidth = 0
    }

    private func releaseVelocityWidth(for value: DragGesture.Value) -> CGFloat {
        let predictedAdditionalWidth = value.predictedEndTranslation.width - value.translation.width

        // Prefer SwiftUI's predicted end translation when it contains useful inertia information,
        // but fall back to our measured drag velocity for short gestures where prediction is weak.
        guard abs(predictedAdditionalWidth) > Self.minimumPublishDistanceWidth else {
            return boostedVelocityWidth(dragVelocityWidth)
        }

        let decelerationRate = CGFloat(Self.scrollDecelerationRate)

        guard decelerationRate > 0, decelerationRate < 1 else {
            return boostedVelocityWidth(dragVelocityWidth)
        }

        let predictedVelocityWidth = predictedAdditionalWidth * 1000 * (1 - decelerationRate) / decelerationRate
        let releaseVelocityWidth = abs(predictedVelocityWidth) > abs(dragVelocityWidth) ? predictedVelocityWidth : dragVelocityWidth

        return boostedVelocityWidth(releaseVelocityWidth)
    }

    private func startDeceleration(velocityWidth: CGFloat, chartWidth: CGFloat) {
        guard abs(velocityWidth) >= Self.minimumDecelerationVelocityWidth else { return }

        let timeInterval = TimeInterval(ConstantsGlucoseChart.decelerationTimerValueInSeconds)
        let secondsPerPoint = visibleTimeInterval / max(Double(chartWidth), 1)
        let decelerationRate = Self.scrollDecelerationRate
        // This is the same integral-based deceleration calculation used by `GlucoseChartManager`.
        // Velocity decays by rate^t and the timer applies only the additional distance since the last
        // tick. The coordinator publishes date-window changes; the state manager then appends or
        // prepends data if that new window extends beyond the current cache.
        let initialDistanceConstant = Double(velocityWidth) / log(decelerationRate)
        let startTime = Date()
        var distanceTravelled: CGFloat = 0

        decelerationTimer = Timer(timeInterval: timeInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()

                return
            }

            let elapsedMilliseconds = Date().timeIntervalSince(startTime) * 1000
            let totalDistanceWidth = CGFloat(round(0.001 * ((Double(velocityWidth) * pow(decelerationRate, elapsedMilliseconds) / log(decelerationRate)) - initialDistanceConstant)))
            let distanceWidth = totalDistanceWidth - distanceTravelled

            guard abs(distanceWidth) >= Self.minimumDecelerationDistanceWidth else {
                self.stopDeceleration()

                return
            }

            let proposedEndDate = self.endDate.addingTimeInterval(-Double(distanceWidth) * secondsPerPoint)
            let clampedEndDate = min(proposedEndDate, Date())

            self.publishEndDate(clampedEndDate, force: true)
            distanceTravelled += distanceWidth

            if proposedEndDate > Date(), velocityWidth < 0 {
                self.stopDeceleration()
            }
        }

        if let decelerationTimer = decelerationTimer {
            RunLoop.main.add(decelerationTimer, forMode: .common)
        }
    }

    private func publishEndDate(_ newEndDate: Date, minimumTimeInterval: TimeInterval = 0, force: Bool = false) {
        guard force || abs(newEndDate.timeIntervalSince(endDate)) >= minimumTimeInterval else { return }

        endDate = newEndDate
    }

    private func boostedVelocityWidth(_ velocityWidth: CGFloat) -> CGFloat {
        let boostedVelocityWidth = velocityWidth * Self.releaseVelocityMultiplier

        return min(abs(boostedVelocityWidth), Self.maximumReleaseVelocityWidth) * (boostedVelocityWidth < 0 ? -1 : 1)
    }

    private static var scrollDecelerationRate: Double {
        min(Double(ConstantsGlucoseChart.decelerationRate) + decelerationRateBoost, maximumDecelerationRate)
    }

}
