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
    
    @State private var showingAlert = false
    
    // save typing
    /// is true if the user is using mg/dL units (pulled from UserDefaults)
    private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    
    /// a common string to show in case a property/value is nil
    private let nilString = "-"
    
    // MARK: - SwiftUI views
    
    var body: some View {
        @State var deviceStatus = nightscoutSyncManager.deviceStatus
        
        NavigationView {
            VStack {
                List {
                    if 1 == 2 {
                        Section(header: Text("Debug")) {
                            row(title: "Last Nightscout check", data: deviceStatus.lastCheckedDate.formatted(date: .omitted, time: .standard))
                            row(title: "Last Updated", data: deviceStatus.updatedDate.formatted(date: .omitted, time: .standard))
                            row(title: "Created At", data: deviceStatus.createdAt.formatted(date: .omitted, time: .standard))
                        }
                    }
                    
                    Section(header: Text("System Status")) {
                        //                        let didLoop = (nightscoutSyncManager.deviceStatus.didLoop ?? false) ? Texts_Common.yes : Texts_Common.no
                        let lastLoop = deviceStatus.lastLoopDate != .distantPast ? nightscoutSyncManager.deviceStatus.lastLoopDate.formatted(date: .omitted, time: .shortened) : nilString
                        let lastLoopAgo = deviceStatus.lastLoopDate != .distantPast ? " (\(deviceStatus.lastLoopDate.daysAndHoursAgo(appendAgo: true)))" : ""
                        let lastUpdate = deviceStatus.createdAt != .distantPast ? nightscoutSyncManager.deviceStatus.createdAt.formatted(date: .omitted, time: .shortened) : nilString
                        let lastUpdateAgo = deviceStatus.createdAt != .distantPast ? " (\(deviceStatus.createdAt.daysAndHoursAgo(appendAgo: true)))" : ""
                        
                        // show the app name and version number if available
                        if let appVersion = deviceStatus.appVersion {
                            if appVersion.count < 10 {
                                row(title: "App name", data: "\(deviceStatus.systemName() ?? nilString) (\(appVersion))")
                                
                                // if the version number string is too long, use two lines
                            } else {
                                HStack {
                                    Text("App name")
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text(deviceStatus.systemName() ?? nilString)
                                            .foregroundColor(.secondary)
                                        Text(appVersion)
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                            
                            // no version number available, so show only the app name
                        } else {
                            row(title: "AID app", data: deviceStatus.systemName() ?? nilString)
                        }
                        
                        if let deviceName = deviceStatus.deviceName() {
                            row(title: "Device", data: deviceName)
                        }
                        
                        if let error = deviceStatus.error {
                            row(title: "Error", data: error.capitalized)
                        }
                        
                        // show the active profile if available (AAPS)
                        if let activeProfile = deviceStatus.activeProfile {
                            row(title: "Active profile", data: activeProfile)
                        }
                        
                        HStack {
                            Text("Uploader battery")
                            Spacer()
                            // show if the uploader is charging (AAPS)
                            if let uploaderBatteryChargingImage = deviceStatus.uploaderBatteryChargingImage() {
                                uploaderBatteryChargingImage.chargingImage
                                    .foregroundStyle(uploaderBatteryChargingImage.chargingColor)
                                    .imageScale(.small)
                            }
                            
                            if let uploaderBatteryImage = deviceStatus.uploaderBatteryImage() {
                                uploaderBatteryImage.batteryImage
                                    .foregroundStyle(uploaderBatteryImage.batteryColor)
                            }
                            
                            Text("\(deviceStatus.uploaderBattery?.description ?? nilString) %")
                                .foregroundColor(.secondary)
                        }
                        
                        row(title: "Last cycle", data: "\(lastUpdate)\(lastUpdateAgo)")
                        
                        row(title: "Last enacted cycle", data: "\(lastLoop)\(lastLoopAgo)")
                    }
                    
                    Section(header: Text("AID Specific")) {
                        row(title: "Temp basal rate", data: (deviceStatus.rate?.round(toDecimalPlaces: 1).description ?? "-") + " U/hr (" + (deviceStatus.duration?.description ?? "-") + " mins)")
                        
                        if let bolusVolume = deviceStatus.bolusVolume {
                            row(title: "Auto-bolus given", data: bolusVolume.round(toDecimalPlaces: 2).stringWithoutTrailingZeroes + " U")
                        }
                        
                        row(title: "IOB", data: (deviceStatus.iob?.round(toDecimalPlaces: 2).stringWithoutTrailingZeroes ?? nilString) + " U")
                        
                        row(title: "COB", data: (deviceStatus.cob?.round(toDecimalPlaces: 0).stringWithoutTrailingZeroes ?? nilString) + " g")
                        
                        if let isf = deviceStatus.isf {
                            row(title: "ISF", data: isf.round(toDecimalPlaces: 0).stringWithoutTrailingZeroes)
                        }
                        
                        if let sensitivityRatio = deviceStatus.sensitivityRatio {
                            row(title: "Autosens", data: sensitivityRatio.round(toDecimalPlaces: 1).description)
                        }
                        
                        if let tdd = deviceStatus.tdd {
                            row(title: "TDD", data: tdd.round(toDecimalPlaces: 1).description + " U")
                        }
                        
                        if let currentTarget = deviceStatus.currentTarget {
                            row(title: "Current target", data: "\(currentTarget.mgDlToMmolAndToString(mgDl: isMgDl)) \(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)")
                        }
                        
                        if let eventualBG = deviceStatus.eventualBG {
                            row(title: "Eventual BG", data: "\(eventualBG.mgDlToMmolAndToString(mgDl: isMgDl)) \(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)")
                        }
                        
                        if let insulinReq = deviceStatus.insulinReq {
                            row(title: "Required insulin", data: insulinReq.round(toDecimalPlaces: 2).description + " U")
                        }
                    }
                    
                    Section(header: Text("Pump")) {
                        // show the pump type if available (Loop)
                        if let pumpManufacturer = deviceStatus.pumpManufacturer {
                            row(title: "Manufacturer", data: pumpManufacturer)
                        }
                        
                        if let pumpModel = deviceStatus.pumpModel {
                            row(title: "Model", data: pumpModel)
                        }
                        
                        if let pumpStatus = deviceStatus.pumpStatus {
                            row(title: "Status", data: pumpStatus.capitalized)
                        }
                        
                        if deviceStatus.pumpManufacturer == "Insulet", deviceStatus.pumpReservoir == ConstantsNightscout.omniPodReservoirFlagNumber {
                            row(title: "Insulin remaining", data: "50+ U")
                        } else {
                            row(title: "Insulin remaining", data: (deviceStatus.pumpReservoir?.round(toDecimalPlaces: 1).description ?? nilString) + " U")
                        }
                        
                        if let pumpBatteryPercent = deviceStatus.pumpBatteryPercent {
                            row(title: "Battery", data: pumpBatteryPercent.description + " %")
                        }
                        
                        if let baseBasalRate = deviceStatus.baseBasalRate {
                            row(title: "Scheduled basal rate", data: baseBasalRate.round(toDecimalPlaces: 1).description + " U/hr")
                        }
                    }
                    
                    if deviceStatus.reason != nil {
                        Section(header: Text("AID response")) {
                            if let reasonValuesArray = deviceStatus.reasonValuesArray() {
                                ForEach(reasonValuesArray, id: \.self) { reasonValue in
                                    Text(reasonValue.trimmingCharacters(in: .whitespaces))
                                        .foregroundStyle(Color(.colorSecondary))
                                }
                                
                            } else {
                                Text("Nothing enacted or suggested in current Nightscout response at \(deviceStatus.updatedDate.formatted(date: .omitted, time: .shortened))")
                            }
                        }
                    }
                }
            }
            .navigationTitle("AID Follow Status")
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
                .foregroundColor(.secondary)
        })
        
        return rowView
    }
}

struct AIDStatusView_Previews: PreviewProvider {
    static var previews: some View {
        AIDStatusView()
    }
}
