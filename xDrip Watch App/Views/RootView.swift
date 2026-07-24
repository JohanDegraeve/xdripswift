//
//  RootView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 21/7/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    var body: some View {
        TabView{
            MainView()
            BigNumberView()
        }
        .modifier(RootViewTabViewStyleModifier())
        .environmentObject(watchState)
    }
}

#if os(watchOS)
struct RootViewTabViewStyleModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content.tabViewStyle(.carousel)
    }
}
#else
struct RootViewTabViewStyleModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content.tabViewStyle(.page)
    }
}
#endif

#Preview {
    RootView()
}
