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
    
    // enum to hold the different views in the picker
    private enum PickerViews: String, Hashable, Identifiable, CaseIterable {
        case deviceStatus
        case profile
        
        var id: String { rawValue }

        var name: String {
            switch self {
            case .deviceStatus:
                return "Device Status"
            case .profile:
                return "Profile"
            }
        }
    }
    
    // store a boolean flag. We'll toggle this with the timer to refresh the view
    @State private var refreshView = false
    
    // store the current pickerview index
    @State private var pickerViewSelected: PickerViews = .deviceStatus
    
    // save typing
    /// is true if the user is using mg/dL units (pulled from UserDefaults)
    private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    
    /// a common string to show in case a property/value is nil
    private let nilString = "-"
    
    /// used to refresh the view every few seconds in case the device status has been updated in the background
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // MARK: - SwiftUI views
    
    var body: some View {
        let profile = nightscoutSyncManager.profile
        let deviceStatus = nightscoutSyncManager.deviceStatus
        
        NavigationView {
            VStack {
                // show a nice colourful header to represent the AID system being followed and the status.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if let systemIcon = deviceStatus.systemIcon() {
                            systemIcon.scaledToFit()
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(deviceStatus.systemName() ?? "Status")
                                .font(.title2).bold()
                                .id(refreshView) // places the refresh here as this text view will always be shown
                            
                            if let appVersion = deviceStatus.appVersion {
                                Text(appVersion.components(separatedBy: "-").first ?? nilString)
                                    .font(.callout).bold()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .foregroundStyle(Color(.colorSecondary))
                            }
                        }
                        
                        Spacer()
                        
                        HStack {
                            deviceStatus.deviceStatusIconImage()
                                .font(.title3).bold()
                                .foregroundStyle(deviceStatus.deviceStatusColor())
                            
                            Text(deviceStatus.deviceStatusTitle())
                                .font(.title3).fontWeight(.semibold)
                                .foregroundStyle(deviceStatus.deviceStatusColor())
                        }
                    }
                    .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                    .background(deviceStatus.deviceStatusBannerBackgroundColor()).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(EdgeInsets(top: 8, leading: 18, bottom: 10, trailing: 18))
                
                // after the header, show a picker view to allow different list views to be displayed
                Picker("Chose Status or Profile", selection: $pickerViewSelected) {
                    ForEach(PickerViews.allCases, id: \.id) { item in
                        Text(item.name)
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(EdgeInsets(top: 0, leading: 18, bottom: 5, trailing: 18))
                
                if pickerViewSelected == .deviceStatus {
                    // this is the main list view for all AID parameters
                    List {
                        Section(header: Text("System Status")) {
                            // if more than a few seconds difference between the last connection and last loop date, then show the connection separately
                            if deviceStatus.lastLoopDate.timeIntervalSince(deviceStatus.createdAt) > 5 {
                                row(title: "Last cycle", data: "\(deviceStatus.createdAt.formatted(date: .omitted, time: .shortened)) (\(deviceStatus.createdAt.daysAndHoursAgo(appendAgo: true)))")
                            }
                            
                            // show the last loop date only if it exists
                            if deviceStatus.lastLoopDate != .distantPast {
                                row(title: "Last loop", data: "\(deviceStatus.lastLoopDate.formatted(date: .omitted, time: .shortened)) (\(deviceStatus.lastLoopDate.daysAndHoursAgo(appendAgo: true)))")
                                
                                // if not, show the nil string rather than just hiding the row. This gives context.
                            } else {
                                row(title: "Last loop", data: nilString)
                            }
                            
                            // show the active profile if available (AAPS)
                            if let activeProfile = deviceStatus.activeProfile {
                                row(title: "Active profile", data: activeProfile)
                            }
                            
                            // show the override enabled if application (Loop)
                            if let overrideIsActive = deviceStatus.overrideActive, overrideIsActive, let overrideName = deviceStatus.overrideName {
                                if let overrideMaxValue = deviceStatus.overrideMaxValue, let overrideMinValue = deviceStatus.overrideMinValue {
                                    row(title: "Override", data: "\(overrideName) (\(overrideMinValue.mgDlToMmolAndToString(mgDl: isMgDl))-\(overrideMaxValue.mgDlToMmolAndToString(mgDl: isMgDl)))")
                                } else {
                                    row(title: "Override", data: "\(overrideName)")
                                }
                            }
                            
                            if let error = deviceStatus.error {
                                HStack(spacing: 8) {
                                    Text("Error")
                                    Spacer()
                                    Text(error)
                                        .foregroundColor(.red)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                        }
                        
                        Section(header: Text("Uploader")) {
                            if let deviceName = deviceStatus.deviceName() {
                                row(title: "Device", data: deviceName)
                            }
                            
                            HStack {
                                Text("Battery")
                                
                                Spacer()
                                
                                // show if the uploader is charging (AAPS)
                                if let uploaderBatteryChargingImage = deviceStatus.uploaderBatteryChargingImage() {
                                    uploaderBatteryChargingImage.image
                                        .foregroundStyle(uploaderBatteryChargingImage.color)
                                        .imageScale(.small)
                                }
                                
                                if let uploaderBatteryImage = deviceStatus.batteryImage(percent: deviceStatus.uploaderBatteryPercent) {
                                    uploaderBatteryImage.image
                                        .foregroundStyle(uploaderBatteryImage.color)
                                }
                                
                                Text("\(deviceStatus.uploaderBatteryPercent?.description ?? nilString) %")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Section(header: Text("\(deviceStatus.systemName() ?? "AID") Specific")) {
                            row(title: "Basal rate", data: (deviceStatus.rate?.round(toDecimalPlaces: 2).description ?? "-") + " U/hr")
                            
                            row(title: "Duration", data: (deviceStatus.duration?.description ?? "-") + " mins")
                            
                            if let bolusVolume = deviceStatus.bolusVolume {
                                row(title: "Auto-bolus given", data: bolusVolume.round(toDecimalPlaces: 2).description + " U")
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
                            // show the pump type if available
                            if let pumpModel = deviceStatus.pumpModel {
                                row(title: "Model", data: "\(deviceStatus.pumpManufacturer ?? "") \(pumpModel)")
                            }
                            
                            if let pumpStatus = deviceStatus.pumpStatus {
                                row(title: "Status", data: pumpStatus.capitalized)
                            }
                            
                            HStack {
                                Text("Battery")
                                
                                Spacer()
                                
                                if let pumpBatteryImage = deviceStatus.batteryImage(percent: deviceStatus.pumpBatteryPercent) {
                                    pumpBatteryImage.image
                                        .foregroundStyle(pumpBatteryImage.color)
                                }
                                
                                Text("\(deviceStatus.pumpBatteryPercent?.description ?? nilString) %")
                                    .foregroundColor(.secondary)
                            }
                            
                            if let pumpReservoir = deviceStatus.pumpReservoir, pumpReservoir == ConstantsNightscout.omniPodReservoirFlagNumber {
                                row(title: "Reservoir", data: "50+ U")
                                
                            } else {
                                if let pumpReservoir = deviceStatus.pumpReservoir {
                                    // show one decimal place if available when less than 10 units
                                    row(title: "Reservoir", data: (pumpReservoir.round(toDecimalPlaces: pumpReservoir < ConstantsHomeView.pumpReservoirUrgent ? 1 : 0).stringWithoutTrailingZeroes) + " U")
                                } else {
                                    row(title: "Reservoir", data: nilString + " U")
                                }
                            }
                            
                            if let baseBasalRate = deviceStatus.baseBasalRate {
                                row(title: "Scheduled basal rate", data: baseBasalRate.round(toDecimalPlaces: 1).description + " U/hr")
                            }
                        }
                        
                        if deviceStatus.reason != nil {
                            Section(header: Text("\(deviceStatus.systemName() ?? "AID") response")) {
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
                        
                        // TODO: DEBUG
                        Section(header: Text("Debug")) {
                            row(title: "Last Nightscout check", data: deviceStatus.lastCheckedDate.formatted(date: .omitted, time: .standard))
                            row(title: "Last device status update", data: deviceStatus.updatedDate.formatted(date: .omitted, time: .standard))
                            row(title: "Created at", data: deviceStatus.createdAt.formatted(date: .omitted, time: .standard))
                            row(title: "Last loop date", data: deviceStatus.lastLoopDate.formatted(date: .omitted, time: .standard))
                        }
                        
                    }
                    
                    // using a simple if/else as only two options are to be used at the moment for the pickerview.
                } else {
                    
                    if profile.profileName == nil {
                        Text("No Profile Data Available")
                            .foregroundStyle(Color(.systemRed))
                            .padding()
                    }
                    
                    List {
                        Section(header: Text("Current Profile Information")) {
                            if let profileName = profile.profileName {
                                row(title: "Name", data: profileName)
                            }
                            
                            row(title: "Started", data: profile.startDate != .distantPast ? "\(profile.startDate.daysAndHoursAgo(appendAgo: true))" : nilString)
                            
                            row(title: "Stored by", data: profile.enteredBy ?? nilString)
                            
                            row(title: "Timezone", data: profile.timezone ?? nilString)
                            
                            if let isMgDl = profile.isMgDl {
                                row(title: "Units", data: isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
                            }
                            
                            if let dia = profile.dia {
                                row(title: "DIA", data: "\(dia.stringWithoutTrailingZeroes) \(Texts_Common.hours)")
                            } else {
                                row(title: "DIA", data: nilString)
                            }
                        }
                        
                        Section(header: Text("Scheduled Basal Rates")) {
                            if let items = profile.basal {
                                ForEach(items, id: \.self) { item in
                                    // conver timeAsSecondsFromMidnight to a real start time to show to the user
                                    let fromHour = Date().toMidnight().addingTimeInterval(TimeInterval(item.timeAsSecondsFromMidnight))
                                    
                                    row(title: fromHour.formatted(date: .omitted, time: .shortened), data: "\(item.value.round(toDecimalPlaces: 2).description) U/hr")
                                }
                            } else {
                                Text("No basal rates in profile")
                            }
                        }
                        
                        Section(header: Text("Scheduled ISF")) {
                            if let items = profile.sensitivity {
                                ForEach(items, id: \.self) { item in
                                    // conver timeAsSecondsFromMidnight to a real start time to show to the user
                                    let fromHour = Date().toMidnight().addingTimeInterval(TimeInterval(item.timeAsSecondsFromMidnight))
                                    
                                    row(title: fromHour.formatted(date: .omitted, time: .shortened), data: "\(item.value.stringWithoutTrailingZeroes) U")
                                }
                            } else {
                                Text("No ISF stored in profile")
                            }
                        }
                        
                        Section(header: Text("Scheduled Carb Ratios")) {
                            if let items = profile.carbratio {
                                ForEach(items, id: \.self) { item in
                                    // conver timeAsSecondsFromMidnight to a real start time to show to the user
                                    let fromHour = Date().toMidnight().addingTimeInterval(TimeInterval(item.timeAsSecondsFromMidnight))
                                    
                                    row(title: fromHour.formatted(date: .omitted, time: .shortened), data: "\(item.value.round(toDecimalPlaces: 1).description) g")
                                }
                            } else {
                                Text("No carb ratios stored in profile")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Follow Status")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }
            }
            .onReceive(timer, perform: { _ in
                refreshView.toggle()
            })
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

struct AIDStatusView_Previews: PreviewProvider {
    static var previews: some View {
        AIDStatusView()
    }
}
