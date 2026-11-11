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
    @State private var showsCollectedReadings = false
    @State private var showsDirectWatchAlerts = false
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RootView(onCollectedReadings: { showsCollectedReadings = true },
                         onAlerts: { showsDirectWatchAlerts = true })
                    // Carousel pages are lazy. Register destinations directly at the stack root.
                    .navigationDestination(isPresented: $showsCollectedReadings) {
                        DirectWatchCollectedReadingsView(collector: watchState.directWatchCollector)
                    }
                    .navigationDestination(isPresented: $showsDirectWatchAlerts) {
                        DirectWatchAlertsView(collector: watchState.directWatchCollector)
                    }
            }.environmentObject(watchState)
        }
        
        #if os(watchOS)
        .backgroundTask(.bluetoothAlert) {
            await watchState.directWatchCollector.handleBluetoothBackground()
        }
        #endif

        // assign the custom view controller to show all watch notifications with snoozeCategory (which will be most of them)
        #if canImport(WatchKit)
        WKNotificationScene(controller: NotificationController.self, category: "snoozeCategoryIdentifier")
        #endif
    }
}
