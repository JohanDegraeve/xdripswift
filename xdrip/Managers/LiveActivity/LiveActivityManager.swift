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

/// manager class to handle the live activity events
public final class LiveActivityManager {
    // MARK: - Private variables
    
    private var eventAttributes: XDripWidgetAttributes
    private var eventActivity: Activity<XDripWidgetAttributes>?
    
    // Debounced update task
    private var debouncedUpdateTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.5
    
    // initialize an "empty" contentState and use this to hold the current context state of the live activity after each start/update
    // this makes it much easier to restart from an App Intent without needing to generate a new context to send
    private var persistentContentState = XDripWidgetAttributes.ContentState(bgReadingValues: [0], bgReadingDates: [.now], isMgDl: true, slopeOrdinal: 0, deltaValueInUserUnit: 0, urgentLowLimitInMgDl: 0, lowLimitInMgDl: 0, highLimitInMgDl: 0, urgentHighLimitInMgDl: 0, liveActivityType: .normal, dataSourceDescription: "", deviceStatusCreatedAt: .now, deviceStatusLastLoopDate: .now)
    
    // the start date of the event so when know track when to proactively end/restart the activity
    private var eventStartDate: Date
    
    // static shared singleton of LiveActivityManager
    static let shared = LiveActivityManager()
    
    // for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLiveActivityManager)
    
    // initializer - declared as private to prevent outside initialization (due to singleton useage intent)
    private init() {
        eventAttributes = XDripWidgetAttributes()
        eventStartDate = Date()
    }
}

// MARK: - Helper Extension

extension LiveActivityManager {
    /// Public API: Debounced update entry point
    func update(contentState: XDripWidgetAttributes.ContentState, forceRestart: Bool = false) {
        debouncedUpdateTask?.cancel()
        debouncedUpdateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.debounceInterval ?? 0.5 * 1_000_000_000))
            await self?.ensureActivity(contentState: contentState, forceRestart: forceRestart)
        }
    }

    /// Public API: End all activities
    @MainActor
    func endAll() async {
        for activity in Activity<XDripWidgetAttributes>.activities {
            trace("in endAll, ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: activity.id))
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        eventActivity = nil
    }

    /// Public API: Restart from intent/shortcut
    @MainActor
    func restartFromIntent() {
        Task { [weak self] in
            guard let self = self else { return }
            await self.endAll()
            await self.ensureActivity(contentState: self.persistentContentState)
        }
    }

    /// Recover orphaned activities if needed. This likely won't usually be needed often but if we can do it, then we will avoid
    /// leaving an orphaned live activity on the lock screen
    @MainActor
    private func recoverOrphanedActivityIfNeeded() async {
        if eventActivity == nil {
            let existing = Activity<XDripWidgetAttributes>.activities.first
            if let found = existing {
                eventActivity = found
                if persistentContentState.urgentLowLimitInMgDl > 0 {
                    await ensureActivity(contentState: persistentContentState)
                }
                trace("in recoverOrphanedActivityIfNeeded, recovered orphaned live activity: %{public}@", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: found.id))
            }
        }
    }

    /// Unifies start/update logic into a single function
    @MainActor
    private func ensureActivity(contentState: XDripWidgetAttributes.ContentState, forceRestart: Bool = false) async {
        // first let's see if we can recover any orphaned live activities and bring them back into scope
        await recoverOrphanedActivityIfNeeded()
        
        if !ActivityAuthorizationInfo().areActivitiesEnabled {
            trace("in ensureActivity, live activities are disabled in the iPhone Settings or permission has not been given.", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            return
        }
        
        // If no activity, start one and return
        if eventActivity == nil {
            let residualCount = Activity<XDripWidgetAttributes>.activities.count
            if residualCount > 0 {
                trace("in ensureActivity, found %{public}@ residual live activities, ending them before starting a new one", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, residualCount.description)
                await endAll()
            }
            await startActivity(contentState: contentState)
            trace("in ensureActivity, started new live activity", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            return
        }
        
        // If forceRestart is requested, always end and start a new activity, then return
        if forceRestart {
            await endAll()
            await startActivity(contentState: contentState)
            trace("in ensureActivity, forceRestart triggered", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            return
        }
        
        // If activity is dismissed or ended, end them, start a new one and return
        if eventActivity?.activityState == .dismissed || eventActivity?.activityState == .ended {
            await endAll()
            await startActivity(contentState: contentState)
            trace("in ensureActivity, restarted live activity after dismissal/end", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            return
        }
        
        // Otherwise, update the currently activity (this would be the normal path)
        await updateActivity(to: contentState)
    }
    
    /// end all live activities that are spawned from the app
    func endAllActivities() async {
        for activity in Activity<XDripWidgetAttributes>.activities {
            trace("in endAllActivities, ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: activity.id))
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        // reset local handle
        eventActivity = nil
    }
    
    /// will start a new live activity event based upon the content state passed to the function
    /// - Parameter contentState: the content state of the new activity
    @MainActor
    private func startActivity(contentState: XDripWidgetAttributes.ContentState) async {
        eventStartDate = Date()
        
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
            trace("in startActivity, error: %{public}@", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .error, error.localizedDescription)
        }
    }
    
    /// update the current live activity
    /// - Parameter contentState: the updated context state of the activity
    @MainActor
    private func updateActivity(to contentState: XDripWidgetAttributes.ContentState) async {
        // ...existing code...
        
        if eventActivity?.activityState == .ended {
            trace("in updateActivity, detected .ended state. Starting a new live activity", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            await endAllActivities()
            await startActivity(contentState: contentState)
            return
        }
        
        // check if the activity is dismissed by the user (by swiping away the notification)
        // if so, then end it completely and start a new one
        if eventActivity?.activityState == .dismissed {
            await endAllActivities()
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
    
    /// end the live activity if it is being shown, do nothing if there is no eventyActivity
    @MainActor
    private func endActivity() async {
        if eventActivity != nil {
            for activity in Activity<XDripWidgetAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
                trace("in endActivity, ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: activity.id))
            }
            eventActivity = nil
        }
    }
}
