//
//  xDripWatchApp.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

#if canImport(WatchKit)
import WatchKit
#endif

@main
struct xDrip_Watch_AppApp: App {
    @StateObject var watchState = WatchStateModel()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                RootView()
            }.environmentObject(watchState)
        }
        
        // assign the custom view controller to show all watch notifications with snoozeCategory (which will be most of them)
        #if canImport(WatchKit)
        WKNotificationScene(controller: NotificationController.self, category: "snoozeCategoryIdentifier")
        #endif
    }
}
