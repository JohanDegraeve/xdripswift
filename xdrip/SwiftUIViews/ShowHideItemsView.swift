//
//  ShowHideItemsView.swift
//  xdrip
//
//  Created by Paul Plant on 14/12/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI
import OSLog

struct ShowHideItemsView: View {
    // MARK: - environment objects
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    // MARK: - private @State properties
    
    @State private var showMiniChart = UserDefaults.standard.showMiniChart
    @State private var showStatistics = UserDefaults.standard.showStatistics
    @State private var showTreatmentsOnChart = UserDefaults.standard.showTreatmentsOnChart
    @State private var speakReadings = UserDefaults.standard.speakReadings
    @State private var allowStandByHighContrast = UserDefaults.standard.allowStandByHighContrast
    @State private var forceStandByBigNumbers = UserDefaults.standard.forceStandByBigNumbers
    
    // MARK: - private properties
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    // MARK: - SwiftUI views
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Home Screen"), footer: Text("Show or hide main home screen elements, useful when using smaller iPhone screen sizes")) {
                        Toggle(Texts_SettingsView.showMiniChart, isOn: $showMiniChart)
                            .onChange(of: showMiniChart) { newValue in
                                UserDefaults.standard.showMiniChart = newValue
                            }
                        
                        Toggle(Texts_SettingsView.labelShowStatistics, isOn: $showStatistics)
                            .onChange(of: showStatistics) { newValue in
                                UserDefaults.standard.showStatistics = newValue
                            }
                    }
                    
                    Section(header: Text("Glucose Chart")) {
                        Toggle(Texts_SettingsView.settingsviews_showTreatments, isOn: $showTreatmentsOnChart)
                            .onChange(of: showTreatmentsOnChart) { newValue in
                                UserDefaults.standard.showTreatmentsOnChart = newValue
                            }
                    }
                    
                    Section(header: Text("StandBy Mode"), footer: Text("Changes how the StandBy mode will be displayed if activated in the iPhone settings")) {
                        Toggle(Texts_SettingsView.allowStandByHighContrast, isOn: $allowStandByHighContrast)
                            .onChange(of: allowStandByHighContrast) { newValue in
                                UserDefaults.standard.allowStandByHighContrast = newValue
                            }
                        
                        Toggle(Texts_SettingsView.forceStandByBigNumbers, isOn: $forceStandByBigNumbers)
                            .onChange(of: forceStandByBigNumbers) { newValue in
                                UserDefaults.standard.forceStandByBigNumbers = newValue
                            }
                    }
                    
                    Section(header: Text("Additional Items")) {
                        Toggle(Texts_SettingsView.labelSpeakBgReadings, isOn: $speakReadings)
                            .onChange(of: speakReadings) { newValue in
                                UserDefaults.standard.speakReadings = newValue
                            }
                    }
                }
            }
            .navigationTitle(Texts_HomeView.showHideItemsTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }
            }
        }
        .colorScheme(.dark)
    }
    
    // MARK: - private functions
    
    /// returns a row view so that all rows are the same
    /// - parameters:
    ///   - title: the title text
    ///   - data: the value text
    /// - returns:
    ///   - a view with the formatted row inside it
    private func row(title: String, data: String) -> AnyView {
        // wrap the HStack in an AnyView so that it can be returned back to the caller
        let rowView = AnyView(HStack {
            Text(title)
            Spacer()
            Text(data)
                .foregroundStyle(Color(.colorSecondary))
        })
        
        return rowView
    }
}

struct ShowHideItemsView_Previews: PreviewProvider {
    static var previews: some View {
        ShowHideItemsView()
    }
}

    //                    Section(header: Text(Texts_SettingsView.showMiniChart)) {
    //                        HStack(alignment: .center, spacing: 20) {
    //                            Image("showHide_showMiniChart")
    //                                .resizable()
    //                                .scaledToFill()
    //                            Toggle("", isOn: $showMiniChart)
    //                                .onChange(of: showStatistics) { newValue in
    //                                    UserDefaults.standard.showMiniChart = newValue
    //                                }
    //                        }
    //                    }
