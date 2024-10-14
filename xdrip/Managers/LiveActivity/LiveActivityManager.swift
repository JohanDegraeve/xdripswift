//
//  LiveActivityManager.swift
//  xdrip
//
//  Created by Paul Plant on 31/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import ActivityKit
import OSLog
import SwiftUI

/// manager class to handle the live activity events
public final class LiveActivityManager {
    
    // MARK: - Private variables
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLiveActivityManager)
    
    private var eventAttributes: XDripWidgetAttributes
    private var eventActivity: Activity<XDripWidgetAttributes>?
    
    // the start date of the event so when know track when to proactively end/restart the activity
    private var eventStartDate: Date
    
    static let shared = LiveActivityManager()
    
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
                trace("in runActivity, starting new live activity", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                startActivity(contentState: contentState)
            } else if forceRestart && eventStartDate < Date().addingTimeInterval(-ConstantsLiveActivity.allowLiveActivityRestartAfterMinutes) {
                // force an end/start cycle of the activity when the app comes to the foreground assuming at least 'x' hours have passed. This restarts the 8 hour limit.
                trace("in runActivity, restarting live activity", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                Task {
                    await endActivity()
                    startActivity(contentState: contentState)
                }
            } else if eventStartDate < Date().addingTimeInterval(-ConstantsLiveActivity.endLiveActivityAfterMinutes) {
                // if the activity has been running for almost 8 hours, proactively end the activity before it goes stale
                trace("in runActivity, ending live activity on purpose to avoid staying on the screen when stale", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                Task {
                    await endActivity()
                }
            } else {
                // none of the above conditions are true so let's just update the activity
                trace("in runActivity, updating live activity", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                Task {
                    await updateActivity(to: contentState)
                }
            }
        } else {
            trace("in runActivity, live activities are disabled in the iPhone Settings or permission has not been given.", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
        }
    }
    
    
    /// end all live activities that are spawned from the app
    func endAllActivities() {
        
        // https://developer.apple.com/forums/thread/732418
        // Add a semaphore to force it to wait for the activities to end before returning from the method
        let semaphore = DispatchSemaphore(value: 0)
        
        Task
        {
            for activity in Activity<XDripWidgetAttributes>.activities {
                let idString = "\(String(describing: eventActivity?.id))"
                trace("Ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, idString)
                
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
        
        // as we're starting a new activity in the current event, let's set the eventStartDate so we can track how long it has been running
        eventStartDate = Date()
        var updatedContentState = contentState
        updatedContentState.warnUserToOpenApp = false
        updatedContentState.eventStartDate = Date()
        
        let content = ActivityContent(state: updatedContentState, staleDate: nil, relevanceScore: 1.0)
        
        do {
            eventActivity = try Activity.request(
                attributes: eventAttributes,
                content: content,
                pushType: nil
            )
            let idString = "\(String(describing: eventActivity?.id))"
            
            trace("new live activity started: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, idString)
        } catch {
            trace("error: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, error.localizedDescription)
        }
    }
    
    /// update the current live activity
    /// - Parameter contentState: the updated context state of the activity
    private func updateActivity(to contentState: XDripWidgetAttributes.ContentState) async {
        
        // check if the activity is dismissed by the user (by swiping away the notification)
        // if so, then end it completely and start a new one
        if eventActivity?.activityState == .dismissed {
            Task {
                trace("Previous live activity was dismissed by the user so it will be ended and will try to start a new one.", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                endAllActivities()
                
                startActivity(contentState: contentState)
            }
        } else {
            // update the warnUserToOpenApp flag if needed and then update the activity
            var updatedContentState = contentState
            
            // if the event was started more than 'x' time ago, then let's inform the user that the live activity will soon end so that they open the app
            updatedContentState.warnUserToOpenApp = eventStartDate < Date().addingTimeInterval(-ConstantsLiveActivity.warnLiveActivityAfterMinutes) ? true : false
            
            let updatedContent = ActivityContent(state: updatedContentState, staleDate: nil)
            
            await eventActivity?.update(updatedContent)
        }
    }
    
    /// end the live activity if it is being shown, do nothing if there is no eventyActivity
    private func endActivity() async {
        
        if eventActivity != nil {
            Task {
                for activity in Activity<XDripWidgetAttributes>.activities
                {
                    let idString = "\(String(describing: eventActivity?.id))"
                    trace("Ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, idString)
                    
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            eventActivity = nil
        }
    }
}
