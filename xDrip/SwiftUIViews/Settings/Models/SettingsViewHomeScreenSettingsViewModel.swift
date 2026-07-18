//
//  SettingsViewHomeScreenSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 09/06/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import SwiftUI

fileprivate enum Setting:Int, CaseIterable {
    
    // allow the homescreen to be show a landscape chart when rotated?
    case allowScreenRotation = 0
    
    // show a clock at the bottom of the home screen when the screen lock is activated?
    case showClockWhenScreenIsLocked = 1
    
    // type of semi-transparent dark overlay to cover the app when the screen is locked
    case screenLockDimmingType = 2
    
    // show a fixed scale mini-chart under the main scrollable chart?
    case showMiniChart = 3
    
    // allow the main chart y-axis to auto rescale to the current chart values?
    case allowMainChartAutoReset = 4

    // show the original glucose readings on the main chart when post processing is enabled?
    case showOriginalBGReadings = 5

    // show short-term sensor noise as background bands on the main chart?
    case showSensorNoiseOnChart = 6
    
    //urgent high value
    case urgentHighMarkValue = 7
    
    //high value
    case highMarkValue = 8
    
    //target value
    case targetMarkValue = 9
    
    //low value
    case lowMarkValue = 10
    
    //urgent low value
    case urgentLowMarkValue = 11

    // show the active sensor lifetime as time remaining instead of time elapsed?
    case preferSensorCountdown = 12
    
}

enum SettingsViewHomeScreenSettingsRowGroup {
    case all
    case homeScreen
    case mainChart
    case miniChart
    case sensorLifetime
    case screenLock
    case glucoseRanges
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewHomeScreenSettingsViewModel: NSObject, SettingsViewModelProtocol {

    private let rowGroup: SettingsViewHomeScreenSettingsRowGroup

    init(rowGroup: SettingsViewHomeScreenSettingsRowGroup = .all) {
        self.rowGroup = rowGroup

        super.init()

        addObservers()
    }

    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let mainChartRows = [
            nativeSettingsRow(id: "homeScreen.showOriginalBGReadings", index: Setting.showOriginalBGReadings.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.showSensorNoiseOnChart", index: Setting.showSensorNoiseOnChart.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.allowMainChartAutoReset", index: Setting.allowMainChartAutoReset.rawValue, sectionID: sectionID)
        ]

        let miniChartRows = [
            nativeSettingsRow(id: "homeScreen.showMiniChart", index: Setting.showMiniChart.rawValue, sectionID: sectionID)
        ]

        let screenLockRows = [
            nativeSettingsRow(id: "homeScreen.allowScreenRotation", index: Setting.allowScreenRotation.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.showClockWhenScreenIsLocked", index: Setting.showClockWhenScreenIsLocked.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.screenLockDimmingType", index: Setting.screenLockDimmingType.rawValue, sectionID: sectionID)
        ]

        let sensorLifetimeRows = [
            nativeSettingsRow(id: "homeScreen.preferSensorCountdown", index: Setting.preferSensorCountdown.rawValue, sectionID: sectionID)
        ]

        let glucoseRangeRows = [
            nativeSettingsRow(id: "homeScreen.urgentHighMarkValue", index: Setting.urgentHighMarkValue.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.highMarkValue", index: Setting.highMarkValue.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.targetMarkValue", index: Setting.targetMarkValue.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.lowMarkValue", index: Setting.lowMarkValue.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "homeScreen.urgentLowMarkValue", index: Setting.urgentLowMarkValue.rawValue, sectionID: sectionID)
        ]

        switch rowGroup {
        case .all:
            return mainChartRows + miniChartRows + sensorLifetimeRows + screenLockRows + glucoseRangeRows
        case .homeScreen:
            return mainChartRows + miniChartRows + sensorLifetimeRows + screenLockRows
        case .mainChart:
            return mainChartRows
        case .miniChart:
            return miniChartRows
        case .sensorLifetime:
            return sensorLifetimeRows
        case .screenLock:
            return screenLockRows
        case .glucoseRanges:
            return glucoseRangeRows
        }
    }

    var sectionReloadClosure: (() -> Void)?

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .allowScreenRotation:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.allowScreenRotation },
                setIsOn: { UserDefaults.standard.allowScreenRotation = $0 }
            )
        case .showClockWhenScreenIsLocked:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.showClockWhenScreenIsLocked },
                setIsOn: { UserDefaults.standard.showClockWhenScreenIsLocked = $0 }
            )
        case .showMiniChart:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.showMiniChart },
                setIsOn: { UserDefaults.standard.showMiniChart = $0 }
            )
        case .allowMainChartAutoReset:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.allowMainChartAutoReset },
                setIsOn: { UserDefaults.standard.allowMainChartAutoReset = $0 }
            )
        case .showOriginalBGReadings:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.showOriginalBGReadings },
                setIsOn: { UserDefaults.standard.showOriginalBGReadings = $0 }
            )
        case .showSensorNoiseOnChart:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.showSensorNoiseOnChart },
                setIsOn: { UserDefaults.standard.showSensorNoiseOnChart = $0 }
            )
        case .preferSensorCountdown:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.preferSensorCountdown },
                setIsOn: { UserDefaults.standard.preferSensorCountdown = $0 }
            )
        case .screenLockDimmingType, .urgentHighMarkValue, .highMarkValue, .targetMarkValue, .lowMarkValue, .urgentLowMarkValue:
            return nil
        }
    }
    
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}

    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentHighValue, message: Texts_SettingsView.urgentHighValueMessage, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentHighMarkInMgdl.description, fieldTitle: Texts_Common.enterValue, unitText: glucoseUnitText, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentHighMarkValue:String) in UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded = urgentHighMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .highMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelHighValue, message: Texts_SettingsView.highValueMessage, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.highMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultHighMarkInMgdl.description, fieldTitle: Texts_Common.enterValue, unitText: glucoseUnitText, actionTitle: nil, cancelTitle: nil, actionHandler: {(highMarkValue:String) in UserDefaults.standard.highMarkValueInUserChosenUnitRounded = highMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .targetMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTargetValue, message: Texts_SettingsView.targetValueMessage, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.targetMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultTargetMarkInMgdl.description, fieldTitle: Texts_Common.enterValue, unitText: glucoseUnitText, actionTitle: nil, cancelTitle: nil, actionHandler: {(targetMarkValue:String) in UserDefaults.standard.targetMarkValueInUserChosenUnitRounded = targetMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .lowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelLowValue, message: Texts_SettingsView.lowValueMessage, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.lowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultLowMarkInMgdl.description, fieldTitle: Texts_Common.enterValue, unitText: glucoseUnitText, actionTitle: nil, cancelTitle: nil, actionHandler: {(lowMarkValue:String) in UserDefaults.standard.lowMarkValueInUserChosenUnitRounded = lowMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .urgentLowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentLowValue, message: Texts_SettingsView.urgentLowValueMessage, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl.description, fieldTitle: Texts_Common.enterValue, unitText: glucoseUnitText, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentLowMarkValue:String) in UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded = urgentLowMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .allowScreenRotation:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.allowScreenRotation {
                    UserDefaults.standard.allowScreenRotation = false
                } else {
                    UserDefaults.standard.allowScreenRotation = true
                }
            })
            
        case .showClockWhenScreenIsLocked:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showClockWhenScreenIsLocked {
                    UserDefaults.standard.showClockWhenScreenIsLocked = false
                } else {
                    UserDefaults.standard.showClockWhenScreenIsLocked = true
                }
            })
            
        case .screenLockDimmingType:
            
            // data to be displayed in list from which user needs to pick a screen dimming type
            var data = [String]()

            var selectedRow: Int?

            var index = 0
            
            let currentScreenLockDimmingType = UserDefaults.standard.screenLockDimmingType
            
            // get all data source types and add the description to data. Search for the type that matches the ScreenLockDimmingType that is currently stored in userdefaults.
            for dimmingType in ScreenLockDimmingType.allCases {
                
                data.append(dimmingType.description)
                
                if dimmingType == currentScreenLockDimmingType {
                    selectedRow = index
                }
                
                index += 1
                
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.screenLockDimmingTypeWhenScreenIsLocked, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                if index != selectedRow {
                    
                    UserDefaults.standard.screenLockDimmingType = ScreenLockDimmingType(rawValue: index) ?? .disabled
                    
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .showMiniChart:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showMiniChart {
                    UserDefaults.standard.showMiniChart = false
                } else {
                    UserDefaults.standard.showMiniChart = true
                }
            })
            
        case .allowMainChartAutoReset:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.allowMainChartAutoReset {
                    UserDefaults.standard.allowMainChartAutoReset = false
                } else {
                    UserDefaults.standard.allowMainChartAutoReset = true
                }
            })
            
        case .showOriginalBGReadings:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showOriginalBGReadings {
                    UserDefaults.standard.showOriginalBGReadings = false
                } else {
                    UserDefaults.standard.showOriginalBGReadings = true
                }
            })

        case .showSensorNoiseOnChart:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showSensorNoiseOnChart {
                    UserDefaults.standard.showSensorNoiseOnChart = false
                } else {
                    UserDefaults.standard.showSensorNoiseOnChart = true
                }
            })

        case .preferSensorCountdown:
            return SettingsSelectedRowAction.callFunction(function: {
                UserDefaults.standard.preferSensorCountdown.toggle()
            })
        }
    }
    
    func sectionTitle() -> String? {
        switch rowGroup {
        case .mainChart:
            return Texts_SettingsView.homeScreenChartDisplaySectionTitle

        case .miniChart:
            return nil

        case .sensorLifetime:
            return Texts_SettingsView.homeScreenSensorLifetimeSectionTitle

        case .screenLock:
            return Texts_SettingsView.homeScreenScreenLockSectionTitle

        case .glucoseRanges:
            return Texts_SettingsView.glucoseRangesSectionTitle

        case .all, .homeScreen:
            return Texts_SettingsView.sectionTitleHomeScreen
        }
    }

    func settingsSectionFooter() -> String? {
        switch rowGroup {
        case .mainChart:
            return Texts_SettingsView.homeScreenMainChartSectionFooter

        case .miniChart:
            return nil

        case .sensorLifetime:
            return Texts_SettingsView.homeScreenSensorLifetimeSectionFooter

        case .screenLock:
            return Texts_SettingsView.homeScreenScreenLockSectionFooter

        case .glucoseRanges:
            return Texts_SettingsView.glucoseRangesSectionFooter

        case .all, .homeScreen:
            return nil
        }
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .allowScreenRotation:
            return Texts_SettingsView.allowScreenRotation
            
        case .showClockWhenScreenIsLocked:
            return Texts_SettingsView.showClockWhenScreenIsLocked
            
        case .screenLockDimmingType:
            return Texts_SettingsView.screenLockDimmingTypeWhenScreenIsLocked
            
        case .showMiniChart:
            return Texts_SettingsView.showMiniChart
            
        case .allowMainChartAutoReset:
            return Texts_SettingsView.allowMainChartAutoReset

        case .showOriginalBGReadings:
            return Texts_SettingsView.showOriginalBGReadings

        case .showSensorNoiseOnChart:
            return Texts_SettingsView.showSensorNoiseOnChart

        case .preferSensorCountdown:
            return Texts_SettingsView.preferSensorCountdown

        case .urgentHighMarkValue:
            return Texts_SettingsView.labelUrgentHighValue
            
        case .highMarkValue:
            return Texts_SettingsView.labelHighValue
            
        case .targetMarkValue:
            return Texts_SettingsView.labelTargetValue
            
        case .lowMarkValue:
            return Texts_SettingsView.labelLowValue
            
        case .urgentLowMarkValue:
            return Texts_SettingsView.labelUrgentLowValue
        }
    }

    /// Returns the colour for the small SwiftUI dot shown beside the glucose
    /// threshold rows. The row title stays as plain localized text, and SwiftUI
    /// decides whether to draw the indicator.
    func rowIndicatorColor(index: Int) -> Color? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .urgentHighMarkValue, .urgentLowMarkValue:
            return .red

        case .highMarkValue, .lowMarkValue:
            return .yellow

        case .targetMarkValue:
            return .green

        default:
            return nil
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .screenLockDimmingType, .urgentHighMarkValue, .highMarkValue, .lowMarkValue, .urgentLowMarkValue, .targetMarkValue:
            return SettingsAccessory.disclosure
            
        case .allowScreenRotation, .showClockWhenScreenIsLocked, .showMiniChart, .allowMainChartAutoReset, .showOriginalBGReadings, .showSensorNoiseOnChart, .preferSensorCountdown:
            return SettingsAccessory.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return glucoseDetailText(for: UserDefaults.standard.urgentHighMarkValueInUserChosenUnit)
            
        case .highMarkValue:
            return glucoseDetailText(for: UserDefaults.standard.highMarkValueInUserChosenUnit)
            
        case .targetMarkValue:
            return UserDefaults.standard.targetMarkValueInUserChosenUnit == 0 ? Texts_Common.disabled : glucoseDetailText(for: UserDefaults.standard.targetMarkValueInUserChosenUnit)
            
        case .lowMarkValue:
            return glucoseDetailText(for: UserDefaults.standard.lowMarkValueInUserChosenUnit)
            
        case .urgentLowMarkValue:
            return glucoseDetailText(for: UserDefaults.standard.urgentLowMarkValueInUserChosenUnit)
            
        case .screenLockDimmingType:
            return UserDefaults.standard.screenLockDimmingType.description
            
        case .allowScreenRotation, .showClockWhenScreenIsLocked, .showMiniChart, .allowMainChartAutoReset, .showOriginalBGReadings, .showSensorNoiseOnChart, .preferSensorCountdown:
            return nil
            
        }
    }

    /// Formats the glucose threshold detail text with the current unit.
    /// These Settings rows have enough space now, so the value and unit can live
    /// together on the right-hand side.
    private func glucoseDetailText(for value: Double) -> String {
        return value.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + glucoseUnitText
    }

    /// Returns the current glucose unit text used beside glucose threshold values.
    private var glucoseUnitText: String {
        UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
    }

    // MARK: - observe functions

    private func addObservers() {

        // Listen for changes in the showMiniChart to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showMiniChart.rawValue, options: .new, context: nil)

        // Listen for changes in the showOriginalBGReadings to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showOriginalBGReadings.rawValue, options: .new, context: nil)

        // Listen for changes in the showSensorNoiseOnChart to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.showSensorNoiseOnChart.rawValue, options: .new, context: nil)

    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }

        switch keyPathEnum {
        case UserDefaults.Key.showMiniChart, UserDefaults.Key.showOriginalBGReadings, UserDefaults.Key.showSensorNoiseOnChart:

            // we have to run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }

        default:
            break

        }
    }

}
