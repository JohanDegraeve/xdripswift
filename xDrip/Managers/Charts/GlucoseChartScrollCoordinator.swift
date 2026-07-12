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
/// Gesture handling changes the visible time window, and the data manager responds by extending or
/// cleaning its local cache. Keeping this coordinator free of Core Data and chart marks allows reuse
/// by any interactive glucose chart.
final class GlucoseChartScrollCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var endDate: Date

    // MARK: - Configuration

    private(set) var visibleTimeInterval: TimeInterval

    // MARK: - Drag and Deceleration State

    /// Drag tracking is stored in points, then converted to seconds using the current chart width.
    ///
    /// Drag distance is converted to time using the inner chart width and visible duration.
    private var dragStartEndDate: Date?
    private var dragLastTranslationWidth: CGFloat?
    private var dragLastUpdateDate: Date?
    private var dragVelocityWidth: CGFloat = 0
    /// Captures the main chart's end date once per mini-chart drag so every update remains relative
    /// to the same starting window rather than accumulating translations.
    private var overviewDragStartEndDate: Date?
    private var decelerationTimer: Timer?

    private static let minimumDecelerationVelocityWidth: CGFloat = 20
    private static let minimumDecelerationDistanceWidth: CGFloat = 1
    private static let minimumPublishDistanceWidth: CGFloat = 1
    private static let maximumReleaseVelocityWidth: CGFloat = 6_000
    /// Small multiplier applied to predicted drag velocity so fast swipes travel far enough.
    private static let releaseVelocityMultiplier: CGFloat = 1.3
    /// Small boost to the normal exponential deceleration rate after a fast release.
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
        overviewDragStartEndDate = nil
        self.visibleTimeInterval = abs(visibleTimeInterval)
    }

    /// Returns the visible window to now and stops any in-flight drag/deceleration state.
    func resetToNow() {
        stopDeceleration()
        publishEndDate(Date(), force: true)
        dragStartEndDate = nil
        overviewDragStartEndDate = nil
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
        // A new touch stops any in-flight deceleration immediately.
        stopDeceleration()
        overviewDragStartEndDate = nil
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

    /// Moves the visible window directly within a fixed overview chart.
    ///
    /// Unlike the main-chart gesture, the overview itself does not scroll: the drag moves its
    /// active-window selection in the same direction as the user's finger.
    func updateVisibleRangeFromOverview(value: DragGesture.Value, overviewStartDate: Date, overviewEndDate: Date, chartWidth: CGFloat) {
        stopDeceleration()

        let baseEndDate = overviewDragStartEndDate ?? endDate
        let overviewTimeInterval = max(overviewEndDate.timeIntervalSince(overviewStartDate), 0)
        let secondsPerPoint = overviewTimeInterval / max(Double(chartWidth), 1)
        let proposedEndDate = baseEndDate.addingTimeInterval(Double(value.translation.width) * secondsPerPoint)

        overviewDragStartEndDate = baseEndDate
        let clampedEndDate = clampedOverviewEndDate(proposedEndDate, overviewStartDate: overviewStartDate, overviewEndDate: overviewEndDate)
        publishEndDate(clampedEndDate, minimumTimeInterval: secondsPerPoint * Double(Self.minimumPublishDistanceWidth))
    }

    /// Applies the final overview translation and ends direct manipulation without inertia.
    func finishUpdatingVisibleRangeFromOverview(value: DragGesture.Value, overviewStartDate: Date, overviewEndDate: Date, chartWidth: CGFloat) {
        updateVisibleRangeFromOverview(value: value, overviewStartDate: overviewStartDate, overviewEndDate: overviewEndDate, chartWidth: chartWidth)
        overviewDragStartEndDate = nil
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

    private func clampedOverviewEndDate(_ proposedEndDate: Date, overviewStartDate: Date, overviewEndDate: Date) -> Date {
        let latestEndDate = min(overviewEndDate, Date())
        // The end date cannot move so far left that the main chart's fixed-width window extends
        // beyond the overview's leading edge.
        let earliestEndDate = overviewStartDate.addingTimeInterval(visibleTimeInterval)

        guard earliestEndDate <= latestEndDate else { return latestEndDate }

        return min(max(proposedEndDate, earliestEndDate), latestEndDate)
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
