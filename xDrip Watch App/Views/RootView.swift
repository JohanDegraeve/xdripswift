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
        .tabViewStyle(.carousel)
        .environmentObject(watchState)
    }
}

#Preview {
    RootView()
}
