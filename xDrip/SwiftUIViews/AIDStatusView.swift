//
//  AIDStatusView.swift
//  xdrip
//
//  Created by Paul Plant on 3/11/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct AIDStatusView: View {
    // MARK: - environment objects
    
    /// reference to nightscoutSyncManager
    @EnvironmentObject var nightscoutSyncManager: NightscoutSyncManager
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    // MARK: - private properties
    
    // save typing
    /// is true if the user is using mg/dL units (pulled from UserDefaults)
    private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    
    // MARK: - SwiftUI views
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Info...")
            }
            .navigationTitle("AID System Info")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }
            }
        }
        .colorScheme(.dark)
        .onAppear {}
    }
    
    // MARK: - private functions
}

struct AIDStatusView_Previews: PreviewProvider {
    static var previews: some View {
        AIDStatusView()
    }
}
