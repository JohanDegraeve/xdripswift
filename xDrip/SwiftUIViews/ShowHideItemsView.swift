//
//  ShowHideItemsView.swift
//  xdrip
//
//  Created by Paul Plant on 14/12/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct ShowHideItemsView: View {
    @Environment(\.presentationMode) private var presentationMode

    // These legacy keys store the inverse of the visible switch. Observe them directly
    // so changes from Settings or Home remain synchronized while this sheet is open.
    @AppStorage(UserDefaults.Key.showTreatmentsOnChart.rawValue) private var hidesTherapy = false
    @AppStorage(UserDefaults.Key.allowScreenRotation.rawValue) private var preventsChartRotation = false
    @AppStorage(UserDefaults.Key.showSensorNoise.rawValue) private var hidesSensorNoise = false
    @AppStorage(UserDefaults.Key.speakReadings.rawValue) private var speakReadings = false
    @AppStorage(UserDefaults.Key.preferLargeSnoozeScreen.rawValue) private var preferLargeSnoozeScreen = true
    @AppStorage(UserDefaults.KeysCharts.chartWidthInHours.rawValue) private var chartWidthInHours = ConstantsGlucoseChart.defaultChartWidthInHours

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(Texts_HomeView.showHideGlucoseChartTitle)) {
                    Picker(Texts_SettingsView.mainChartHours, selection: chartHoursSelection) {
                        ForEach(RootHomeChartRange.allCases, id: \.rawValue) { range in
                            Text(range.settingsTitle).tag(range.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(ConstantsAppColors.rowDetailText)

                    Toggle(Texts_SettingsView.allowScreenRotation, isOn: Binding(
                        get: { !preventsChartRotation },
                        set: { preventsChartRotation = !$0 }
                    ))
                    Toggle(Texts_SettingsView.settingsviews_showTreatments, isOn: Binding(
                        get: { !hidesTherapy },
                        set: { hidesTherapy = !$0 }
                    ))
                    Toggle(Texts_SettingsView.showSensorNoise, isOn: Binding(
                        get: { !hidesSensorNoise },
                        set: { hidesSensorNoise = !$0 }
                    ))
                }

                Section(header: Text(Texts_HomeView.showHideAdditionalItemsTitle)) {
                    Toggle(Texts_SettingsView.labelSpeakBgReadings, isOn: $speakReadings)
                    Toggle(Texts_SettingsView.preferLargeSnoozeScreen, isOn: $preferLargeSnoozeScreen)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: ConstantsAppColors.normal))
            .ipadReadableContentWidth(760)
            .navigationTitle(Texts_HomeView.showHideItemsTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OnlineHelpButton(topic: .quickShowHide)
                }
            }
        }
        .colorScheme(.dark)
    }

    /// Normalizes older stored widths and uses the same preference as Home pinch zoom.
    private var chartHoursSelection: Binding<Double> {
        Binding(
            get: { RootHomeChartRange.closest(to: chartWidthInHours).rawValue },
            set: { chartWidthInHours = $0 }
        )
    }
}

struct ShowHideItemsView_Previews: PreviewProvider {
    static var previews: some View {
        ShowHideItemsView()
    }
}
