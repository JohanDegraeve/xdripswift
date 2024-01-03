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

//@available(iOS 16.2, *)
public final class LiveActivityManager {
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLiveActivityManager)
    
    private var eventAttributes: XDripWidgetAttributes
    private var eventActivity: Activity<XDripWidgetAttributes>?
    static let shared = LiveActivityManager()
    
    private init() {
        eventAttributes = XDripWidgetAttributes(eventStartDate: Date())
    }
    
}

// MARK: - Helpers
//@available(iOS 16.2, *)
extension LiveActivityManager {
    
    /// start or update the live activity based upon whether it currently exists or not
    /// - Parameter contentState: the contentState to show
    func runActivity(contentState: XDripWidgetAttributes.ContentState) {
        
        trace("In runActivity", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
        
        // checking whether 'Live activities' is enabled for the app in settings
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            if eventActivity == nil {
                trace("    eventActivity == nil, trying to start new activity", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                startActivity(contentState: contentState)
            } else {
                trace("    eventActivity != nil, trying to update existing", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                Task {
                    await updateActivity(to: contentState)
                }
            }
        } else {
            print("Live activities are disabled in the iPhone Settings or permission has not been given.")
            trace("Live activities are disabled in the iPhone Settings or permission has not been given.", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
        }
    }
    
    func startActivity(contentState: XDripWidgetAttributes.ContentState) {
        
        let content = ActivityContent(state: contentState, staleDate: nil, relevanceScore: 1.0)
        
        do {
            print("Trying to start new live activity")
            eventActivity = try Activity.request(
                attributes: eventAttributes,
                content: content,
                pushType: nil
            )
            print("New activity started: \(String(describing: eventActivity?.id))")
            
            let idString = "\(String(describing: eventActivity?.id))"
            trace("New live activity started: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, idString)
        } catch {
            print(error.localizedDescription)
            
            trace("error: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, error.localizedDescription)
        }
    }
    
    func updateActivity(to contentState: XDripWidgetAttributes.ContentState) async {
        
        // check if the activity is dismissed by the user (by swiping away the notification)
        // if so, then end it completely and start a new one
        if eventActivity?.activityState == .dismissed {
            Task {
                print("Live activity state is \(String(describing: eventActivity?.activityState))")
                
                trace("Previous live activity was dismissed so will end it and try to start a new one.", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info)
                
                endAllActivities()
                
                startActivity(contentState: contentState)
            }
            return
            
        } else {
            await eventActivity?.update(
                ActivityContent<XDripWidgetAttributes.ContentState>(
                    state: contentState,
                    staleDate: Date().addingTimeInterval(10)
                )
            )
        }
    }
    
    /// end the live activity if it is being shown, do nothing if there is no eventyActivity
    func endActivity() {
        
        if eventActivity != nil {
            Task {
                print("Ending live activity: \(String(describing: eventActivity?.id))")
                
                let idString = "\(String(describing: eventActivity?.id))"
                trace("Ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, idString)
                
                await eventActivity?.end(nil, dismissalPolicy: .immediate)
                eventActivity = nil
            }
        }
    }
    
    /// end all live activities that are spawned from the app
    func endAllActivities() {
        
        // https://developer.apple.com/forums/thread/732418
        // Add a semaphore to force it to wait for the activities to end before returning from the method
        let semaphore = DispatchSemaphore(value: 0)
        
        Task
        {
            for activity in Activity<XDripWidgetAttributes>.activities
            {
                print("Force-close detected. Ending Live Activity: \(activity.id)")
                
                let idString = "\(String(describing: eventActivity?.id))"
                trace("Force-close detected. Ending live activity: %{public}@", log: self.log, category: ConstantsLog.categoryLiveActivityManager, type: .info, idString)
                
                await activity.end(nil, dismissalPolicy: .immediate)
                eventActivity = nil
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}
