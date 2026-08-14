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
    @State private var showOriginalBGReadings = UserDefaults.standard.showOriginalBGReadings
    @State private var showTreatmentsOnChart = UserDefaults.standard.showTreatmentsOnChart
    @State private var showSensorNoise = UserDefaults.standard.showSensorNoise
    @State private var speakReadings = UserDefaults.standard.speakReadings
    @AppStorage(UserDefaults.Key.preferLargeSnoozeScreen.rawValue) private var preferLargeSnoozeScreen = true
    
    // MARK: - private properties
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryRootView)
    
    // MARK: - SwiftUI views
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text(Texts_HomeView.showHideHomeScreenTitle), footer: Text(Texts_HomeView.showHideHomeScreenFooter)) {
                        Toggle(Texts_SettingsView.showMiniChart, isOn: $showMiniChart)
                            .onChange(of: showMiniChart) { newValue in
                                UserDefaults.standard.showMiniChart = newValue
                            }
                        
                        Toggle(Texts_SettingsView.labelShowStatistics, isOn: $showStatistics)
                            .onChange(of: showStatistics) { newValue in
                                UserDefaults.standard.showStatistics = newValue
                            }
                    }
                    
                    Section(header: Text(Texts_HomeView.showHideGlucoseChartTitle)) {
                        Toggle(Texts_SettingsView.showOriginalBGReadings, isOn: $showOriginalBGReadings)
                            .onChange(of: showOriginalBGReadings) { newValue in
                                UserDefaults.standard.showOriginalBGReadings = newValue
                            }
                        
                        Toggle(Texts_SettingsView.settingsviews_showTreatments, isOn: $showTreatmentsOnChart)
                            .onChange(of: showTreatmentsOnChart) { newValue in
                                UserDefaults.standard.showTreatmentsOnChart = newValue
                            }

                        Toggle(Texts_SettingsView.showSensorNoise, isOn: $showSensorNoise)
                            .onChange(of: showSensorNoise) { newValue in
                                UserDefaults.standard.showSensorNoise = newValue
                            }
                    }
                    
                    Section(header: Text(Texts_HomeView.showHideAdditionalItemsTitle)) {
                        Toggle(Texts_SettingsView.labelSpeakBgReadings, isOn: $speakReadings)
                            .onChange(of: speakReadings) { newValue in
                                UserDefaults.standard.speakReadings = newValue
                            }

                        // Uses the same stored preference as the full Alarms settings screen.
                        Toggle(Texts_SettingsView.preferLargeSnoozeScreen, isOn: $preferLargeSnoozeScreen)
                    }
                }
                .tint(ConstantsAppColors.normal)
            }
            .ipadReadableContentWidth(760)
            .navigationTitle(Texts_HomeView.showHideItemsTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OnlineHelpButton(topic: .quickShowHide)
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
                .foregroundStyle(ConstantsAppColors.rowTitleText)
            Spacer()
            Text(data)
                .foregroundStyle(ConstantsAppColors.rowDetailText)
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
