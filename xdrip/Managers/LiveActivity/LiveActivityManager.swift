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
    /// start or update the live activity based upon whether it currently exists or not
    /// - Parameter contentState: the contentState to show
    /// - Parameter forceRestart: will force the function to end and restart the live activity
    func runActivity(contentState: XDripWidgetAttributes.ContentState, forceRestart: Bool) {
        // checking whether 'Live activities' is enabled for the app in settings
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            // live activities are enabled. Now check if there is a currently
            // running activity (in which case update it) or if not, start a new one
            if eventActivity == nil {
                startActivity(contentState: contentState)
                trace("in runActivity, starting new live activity", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            } else if forceRestart, eventStartDate < Date().addingTimeInterval(-ConstantsLiveActivity.allowLiveActivityRestartAfterSeconds) {
                // force an end/start cycle of the activity when the app comes to the foreground assuming at least 'x' hours have passed. This restarts the 8 hour limit.
                Task {
                    await endActivity()
                    startActivity(contentState: contentState)
                }
                trace("in runActivity, restarting live activity", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            } else if eventStartDate < Date().addingTimeInterval(-ConstantsLiveActivity.endLiveActivityAfterSeconds) {
                // if the activity has been running for almost 8 hours, proactively end the activity before it goes stale
                Task {
                    await endActivity()
                }
                trace("in runActivity, ending live activity on purpose to avoid staying on the screen when stale", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            } else {
                // none of the above conditions are true so let's just update the activity
                Task {
                    await updateActivity(to: contentState)
                }
                trace("in runActivity, updating live activity", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .debug)
            }
        } else {
            trace("in runActivity, live activities are disabled in the iPhone Settings or permission has not been given.", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
        }
    }
    
    /// Restart Live Activity from LiveActivityIntent/Shortcut
    func restartActivityFromLiveActivityIntent() {
        // when intializing the persistentContentState we set all attributes to zero
        // we can take advantage of this to check that it has really been updated with a real content state
        if persistentContentState.urgentLowLimitInMgDl > 0 {
            endAllActivities()
            startActivity(contentState: persistentContentState)
            trace("in restartActivityFromLiveActivityIntent, restarting live activity from LiveActivityIntent", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
        } else {
            trace("in restartActivityFromLiveActivityIntent, cannot restart live activity from LiveActivityIntent because there is no persistentContentState available yet", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
        }
    }
    
    /// end all live activities that are spawned from the app
    func endAllActivities() {
        // https://developer.apple.com/forums/thread/732418
        // Add a semaphore to force it to wait for the activities to end before returning from the method
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            for activity in Activity<XDripWidgetAttributes>.activities {
                trace("Ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: activity.id))
                
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            semaphore.signal()
        }
        semaphore.wait()
        
        eventActivity = nil
    }
    
    /// will start a new live activity event based upon the content state passed to the function
    /// - Parameter contentState: the content state of the new activity
    private func startActivity(contentState: XDripWidgetAttributes.ContentState) {
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
            
            trace("new live activity started: %{public}@", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: eventActivity?.id))
        } catch {
            trace("error: %{public}@", log: log, category: ConstantsLog.categoryLiveActivityManager, type: .error, error.localizedDescription)
        }
    }
    
    /// update the current live activity
    /// - Parameter contentState: the updated context state of the activity
    private func updateActivity(to contentState: XDripWidgetAttributes.ContentState) async {
        // check if the activity is dismissed by the user (by swiping away the notification)
        // if so, then end it completely and start a new one
        if eventActivity?.activityState == .dismissed {
            Task {
                endAllActivities()
                startActivity(contentState: contentState)
                trace("Previous live activity was dismissed by the user so it will be ended and will try to start a new one.", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
            }
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
    private func endActivity() async {
        if eventActivity != nil {
            Task {
                for activity in Activity<XDripWidgetAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    trace("Ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, String(describing: activity.id))
                }
            }
            eventActivity = nil
        }
    }
}
