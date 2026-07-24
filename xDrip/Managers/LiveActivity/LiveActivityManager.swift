//
//  LiveActivityManager.swift
//  xdrip
//
//  Created by Paul Plant on 31/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import ActivityKit
import Foundation
import OSLog
import SwiftUI
import UIKit

/// manager class to handle the live activity events
public final class LiveActivityManager {
    // MARK: - Private variables
    
    private var eventAttributes: XDripWidgetAttributes
    private var eventActivity: Activity<XDripWidgetAttributes>?
    
    // ActivityKit updates are serialized so a second request cannot race an update already in progress.
    // If another request arrives while ActivityKit is updating, only the newest content needs to follow it.
    private var pendingUpdate: (contentState: XDripWidgetAttributes.ContentState, forceRestart: Bool)?
    private var isUpdating = false
    private var shouldRun = false
    private var commandRevision = 0
    private var backgroundUpdateTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    // initialize an "empty" contentState and use this to hold the current context state of the live activity after each start/update
    // this makes it much easier to restart from an App Intent without needing to generate a new context to send
    private var persistentContentState = XDripWidgetAttributes.ContentState(bgReadingValues: [0], bgReadingDates: [.now], isMgDl: true, slopeOrdinal: 0, deltaValueInUserUnit: 0, urgentLowLimitInMgDl: 0, lowLimitInMgDl: 0, highLimitInMgDl: 0, urgentHighLimitInMgDl: 0, liveActivityType: .normal, dataSourceDescription: "", deviceStatusCreatedAt: .now, deviceStatusLastLoopDate: .now)
    
    // the start date of the event so when know track when to proactively end/restart the activity
    private var eventStartDate: Date
    private var lastStartAttemptDate: Date

    // minimum age an activity must reach before respecting forceRestart requests
    // this is done to prevent unnecessary restarts being performed one after the other
    private let minimumForceRestartAge: TimeInterval = 10
    private let maximumContentStateEncodedBytes = 3_500
    
    // static shared singleton of LiveActivityManager
    static let shared = LiveActivityManager()
    
    // for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLiveActivityManager)
    
    // initializer - declared as private to prevent outside initialization (due to singleton useage intent)
    private init() {
        eventAttributes = XDripWidgetAttributes()
        eventStartDate = Date()
        lastStartAttemptDate = .distantPast
    }
}

// MARK: - Helper Extension

extension LiveActivityManager {
    /// Public API: serialized update entry point
    @MainActor
    func update(contentState: XDripWidgetAttributes.ContentState, forceRestart: Bool = false) {
        let contentState = contentState.limitedForActivityPayload(maximumEncodedBytes: maximumContentStateEncodedBytes)

        commandRevision += 1
        shouldRun = true
        persistentContentState = contentState

        // Keep the newest content, but do not lose a pending restart request when updates are coalesced.
        let shouldForceRestart = forceRestart || pendingUpdate?.forceRestart == true
        pendingUpdate = (contentState, shouldForceRestart)

        beginBackgroundUpdateTaskIfNeeded()
        startProcessingIfNeeded()
    }

    @MainActor
    private func startProcessingIfNeeded() {
        guard shouldRun, pendingUpdate != nil, !isUpdating else { return }

        isUpdating = true
        Task { @MainActor [weak self] in
            await self?.processPendingUpdates()
        }
    }

    @MainActor
    private func processPendingUpdates() async {
        defer {
            isUpdating = false
            endBackgroundUpdateTaskIfNeeded()
        }

        while let update = pendingUpdate {
            pendingUpdate = nil
            await ensureActivity(contentState: update.contentState, forceRestart: update.forceRestart)
        }
    }

    @MainActor
    private func beginBackgroundUpdateTaskIfNeeded() {
        guard backgroundUpdateTaskIdentifier == .invalid else { return }

        // ActivityKit permits background updates, but the app still needs execution time to finish
        // the asynchronous update. Request that time before queuing the processor, as recommended by:
        // https://developer.apple.com/documentation/activitykit/activity/update(_:)
        // https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:)
        backgroundUpdateTaskIdentifier = UIApplication.shared.beginBackgroundTask(
            withName: "Live Activity Update",
            expirationHandler: { [weak self] in
                guard let self else { return }

                trace("in LiveActivityManager, background update task expired", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .error)
                self.endBackgroundUpdateTaskIfNeeded()
            }
        )

        if backgroundUpdateTaskIdentifier == .invalid {
            trace("in LiveActivityManager, could not begin background update task", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .error)
        }
    }

    @MainActor
    private func endBackgroundUpdateTaskIfNeeded() {
        guard backgroundUpdateTaskIdentifier != .invalid else { return }

        let identifier = backgroundUpdateTaskIdentifier
        backgroundUpdateTaskIdentifier = .invalid
        UIApplication.shared.endBackgroundTask(identifier)
    }

    /// Public API: End all activities
    @MainActor
    func endAll() async {
        commandRevision += 1
        let endRevision = commandRevision
        shouldRun = false
        pendingUpdate = nil
        await endActivities()

        // A newer update may arrive while ActivityKit is ending the previous activity. Requeue the
        // latest requested state so that the newer update, rather than the older stop, wins.
        guard shouldRun, commandRevision != endRevision else { return }

        pendingUpdate = (persistentContentState, false)
        startProcessingIfNeeded()
    }

    @MainActor
    private func endActivities() async {
        for activity in Activity<XDripWidgetAttributes>.activities {
            trace("in endAll, ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: activity.id))
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        eventActivity = nil
    }

    /// Public API: Restart from intent/shortcut
    @MainActor
    func restartFromIntent() {
        if (UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat)) && UserDefaults.standard.liveActivityType != .disabled {
            if persistentContentState.urgentLowLimitInMgDl > 0 {
                trace("in restartFromIntent, will try and end/restart current Live Activity", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.commandRevision += 1
                    self.shouldRun = true
                    await self.endActivities()
                    guard self.shouldRun else { return }
                    await self.startActivity(contentState: self.persistentContentState)
                }
            } else {
                trace("in restartFromIntent, cannot restart live activity from Intent because there is no persistentContentState available", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            }
        } else {
            trace("in restartFromIntent, will NOT try and restart Live Activity as not in master or not follower+heartbeat or LAs are not enabled", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)}
    }

    /// Recover orphaned activities if needed. This likely won't usually be needed often but if we can do it, then we will avoid
    /// leaving an orphaned live activity on the lock screen
    @MainActor
    private func recoverOrphanedActivityIfNeeded() async {
        if shouldRun, eventActivity == nil {
            let existing = Activity<XDripWidgetAttributes>.activities.first
            if let found = existing {
                eventActivity = found
                trace("in recoverOrphanedActivityIfNeeded, recovered orphaned live activity: %{public}@", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: found.id))
            }
        }
    }

    /// Unifies start/update logic into a single function
    @MainActor
    private func ensureActivity(contentState: XDripWidgetAttributes.ContentState, forceRestart: Bool = false) async {
        guard shouldRun else { return }

        // first let's see if we can recover any orphaned live activities and bring them back into scope
        await recoverOrphanedActivityIfNeeded()
        
        if !ActivityAuthorizationInfo().areActivitiesEnabled {
            trace("in ensureActivity, live activities are disabled in the iPhone Settings or permission has not been given.", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            return
        }
        
        // If no activity, start one and return
        if eventActivity == nil {
            if !forceRestart && shouldDeferNewStart(contentState: contentState, context: "initial start") {
                return
            }
            let residualCount = Activity<XDripWidgetAttributes>.activities.count
            if residualCount > 0 {
                trace("in ensureActivity, found %{public}@ residual live activities, ending them before starting a new one", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, residualCount.description)
                await endActivities()
            }
            guard shouldRun else { return }
            await startActivity(contentState: contentState)
            trace("in ensureActivity, started new live activity", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            return
        }
        
        // If forceRestart is requested, always end and start a new activity, then return
        if forceRestart {
            let activityAge = Date().timeIntervalSince(eventStartDate)
            if activityAge >= minimumForceRestartAge {
                await endActivities()
                guard shouldRun else { return }
                await startActivity(contentState: contentState)
                let activityAgeString = activityAge < 3600 ? activityAge.minutes.round(toDecimalPlaces: 1).description + " minutes" : activityAge.hours.round(toDecimalPlaces: 1).description + " hours"
                trace("in ensureActivity, forceRestart triggered (existing Live Activity age: %{public}@)", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, activityAgeString)
                return
            } else {
                let activityAgeString = activityAge < 3600 ? activityAge.minutes.round(toDecimalPlaces: 1).description + " minutes" : activityAge.hours.round(toDecimalPlaces: 1).description + " hours"
                trace("in ensureActivity, forceRestart ignored (existing Live Activity age: %{public}@)", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, activityAgeString)
            }
        }
        
        // If activity is dismissed or ended, end them, start a new one and return
        if eventActivity?.activityState == .dismissed || eventActivity?.activityState == .ended {
            if !forceRestart && shouldDeferNewStart(contentState: contentState, context: "restart after dismissal/end") {
                return
            }
            await endActivities()
            guard shouldRun else { return }
            await startActivity(contentState: contentState)
            trace("in ensureActivity, restarted live activity after dismissal/end", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            return
        }
        
        // Otherwise, update the currently activity (this would be the normal path)
        await updateActivity(to: contentState)
    }
    
    /// end all live activities that are spawned from the app
    @MainActor
    func endAllActivities() async {
        await endAll()
    }
    
    /// will start a new live activity event based upon the content state passed to the function
    /// - Parameter contentState: the content state of the new activity
    @MainActor
    private func startActivity(contentState: XDripWidgetAttributes.ContentState) async {
        guard shouldRun else { return }

        let now = Date()
        eventStartDate = now
        lastStartAttemptDate = now
        
        var updatedContentState = contentState
        updatedContentState.warnUserToOpenApp = false
        updatedContentState.eventStartDate = eventStartDate
        
        let content = ActivityContent(state: updatedContentState, staleDate: nil, relevanceScore: 1.0)
        
        do {
            eventActivity = try Activity.request(
                attributes: eventAttributes,
                content: content,
                pushType: nil
            )
            
            // update the persistent content state with the new/updated content state
            persistentContentState = updatedContentState
            
            trace("in startActivity, new live activity started: %{public}@", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: eventActivity?.id))
        } catch {
            eventActivity = nil
            persistentContentState = updatedContentState
            trace("in startActivity, error: %{public}@", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .error, error.localizedDescription)
        }
    }
    
    /// update the current live activity
    /// - Parameter contentState: the updated context state of the activity
    @MainActor
    private func updateActivity(to contentState: XDripWidgetAttributes.ContentState) async {
        guard shouldRun else { return }

        if eventActivity?.activityState == .ended {
            trace("in updateActivity, detected .ended state. Starting a new live activity", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            if shouldDeferNewStart(contentState: contentState, context: "restart after .ended state") {
                return
            }
            await endActivities()
            guard shouldRun else { return }
            await startActivity(contentState: contentState)
            return
        }
        
        // check if the activity is dismissed by the user (by swiping away the notification)
        // if so, then end it completely and start a new one
        if eventActivity?.activityState == .dismissed {
            if shouldDeferNewStart(contentState: contentState, context: "restart after dismissal") {
                return
            }
            await endActivities()
            guard shouldRun else { return }
            await startActivity(contentState: contentState)
            trace("in updateActivity, previous live activity was dismissed by the user so it will be ended and will try to start a new one.", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
        } else {
            // update the warnUserToOpenApp flag if needed and then update the activity
            var updatedContentState = contentState
            
            // if the event was started more than 'x' time ago, then let's inform the user that the live activity will soon end so that they open the app
            updatedContentState.warnUserToOpenApp = eventStartDate < Date().addingTimeInterval(-ConstantsLiveActivity.warnLiveActivityAfterSeconds) ? true : false
            
            // update the persistent content state with the new/updated content state
            persistentContentState = updatedContentState
            
            await eventActivity?.update(ActivityContent(state: updatedContentState, staleDate: nil))
        }
    }
    
    @MainActor
    private func shouldDeferNewStart(contentState: XDripWidgetAttributes.ContentState, context: String) -> Bool {
        let restartThrottleInterval: TimeInterval = 2
        let now = Date()
        let secondsSinceLastStartAttempt = now.timeIntervalSince(lastStartAttemptDate)
        if secondsSinceLastStartAttempt < restartThrottleInterval {
            persistentContentState = contentState
            trace("in LiveActivityManager, throttling %{public}@ (last start %{public}@ seconds ago)", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, context, secondsSinceLastStartAttempt.description)
            return true
        }
        if UIApplication.shared.applicationState != .active {
            persistentContentState = contentState
            trace("in LiveActivityManager, deferring %{public}@ until application becomes active", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, context)
            return true
        }
        lastStartAttemptDate = now
        return false
    }
}
