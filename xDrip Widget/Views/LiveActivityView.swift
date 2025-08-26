//
//  LiveActivityView.swift
//  xdrip
//
//  Created by Paul Plant on 30/7/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WidgetKit

// conditionally show a view with the activity families added if available
struct LiveActivityView: View {
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    
    var body: some View {
        if #available(iOS 18.0, *) {
            LiveActivityViewWithActivityFamily(context: context)
        } else {
            LiveActivityViewWithoutActivityFamily(context: context)
        }
    }
}

@available(iOS 18.0, *)
struct LiveActivityViewWithActivityFamily: View {
    @Environment(\.activityFamily) var activityFamily
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    
    var body: some View {
        if #available(iOS 18.0, *) {
            switch activityFamily {
            case .small:
                LiveActivityViewContentActivityFamilies(context: context)
            case .medium:
                LiveActivityViewContent(context: context)
            @unknown default:
                LiveActivityViewContent(context: context)
            }
        }
    }
}

struct LiveActivityViewWithoutActivityFamily: View {
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    
    var body: some View {
        LiveActivityViewContent(context: context)
    }
}
