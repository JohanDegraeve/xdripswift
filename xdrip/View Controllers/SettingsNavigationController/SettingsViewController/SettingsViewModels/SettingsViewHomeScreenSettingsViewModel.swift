//
//  SettingsViewHomeScreenSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 09/06/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    // allow the homescreen to be show a landscape chart when rotated?
    case allowScreenRotation = 0
    
    // show a clock at the bottom of the home screen when the screen lock is activated?
    case showClockWhenScreenIsLocked = 1
    
    // type of semi-transparent dark overlay to cover the app when the screen is locked
    case screenLockDimmingType = 2
    
    // show a fixed scale mini-chart under the main scrollable chart?
    case showMiniChart = 3
    
    //urgent high value
    case urgentHighMarkValue = 4
    
    //high value
    case highMarkValue = 5
    
    //target value
    case targetMarkValue = 6
    
    //low value
    case lowMarkValue = 7
    
    //urgent low value
    case urgentLowMarkValue = 8
    
    // show glucose predictions on the main chart
    case showPredictions = 9
    
    // automatic algorithm selection
    case autoSelectPredictionAlgorithm = 10
    
    // manual algorithm selection
    case selectPredictionAlgorithm = 11
    
    // include treatments in predictions
    case includeTreatmentsInPredictions = 12
    
    // insulin sensitivity factor (ISF)
    case insulinSensitivityFactor = 13
    
    // carb ratio (ICR)
    case carbRatio = 14
    
    // insulin type selection
    case insulinType = 15
    
    // carb absorption rate
    case carbAbsorptionRate = 16
    
    // carb absorption delay
    case carbAbsorptionDelay = 17
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewHomeScreenSettingsViewModel:SettingsViewModelProtocol {
    
    /// for section reload
    private var sectionReloadClosure: (() -> Void)?
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .allowScreenRotation:
            return UISwitch(isOn: UserDefaults.standard.allowScreenRotation, action: {(isOn:Bool) in UserDefaults.standard.allowScreenRotation = isOn})
            
        case .showClockWhenScreenIsLocked:
            return UISwitch(isOn: UserDefaults.standard.showClockWhenScreenIsLocked, action: {(isOn:Bool) in UserDefaults.standard.showClockWhenScreenIsLocked = isOn})
            
        case .showMiniChart:
            return UISwitch(isOn: UserDefaults.standard.showMiniChart, action: {(isOn:Bool) in UserDefaults.standard.showMiniChart = isOn})
            
        case .showPredictions:
            return UISwitch(isOn: UserDefaults.standard.predictionEnabled, action: {[weak self] (isOn:Bool) in 
                UserDefaults.standard.predictionEnabled = isOn
                // reload section to update enabled states of dependent rows
                self?.sectionReloadClosure?()
            })
            
        case .autoSelectPredictionAlgorithm:
            return UISwitch(isOn: UserDefaults.standard.predictionAutoSelectAlgorithm, action: {[weak self] (isOn:Bool) in 
                UserDefaults.standard.predictionAutoSelectAlgorithm = isOn
                // reload section to update enabled state of algorithm selection row
                self?.sectionReloadClosure?()
            })
            
        case .includeTreatmentsInPredictions:
            return UISwitch(isOn: UserDefaults.standard.predictionIncludeTreatments, action: {[weak self] (isOn:Bool) in 
                UserDefaults.standard.predictionIncludeTreatments = isOn
                // reload section to update enabled states of dependent rows
                self?.sectionReloadClosure?()
            })
            
        case  .screenLockDimmingType, .urgentHighMarkValue, .highMarkValue, .targetMarkValue, .lowMarkValue, .urgentLowMarkValue, .selectPredictionAlgorithm, .insulinSensitivityFactor, .carbRatio, .insulinType, .carbAbsorptionRate, .carbAbsorptionDelay:
            return nil
            
        }
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    func isEnabled(index: Int) -> Bool {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .selectPredictionAlgorithm:
            // Only enabled if predictions are on and auto-select is off
            return UserDefaults.standard.predictionEnabled && !UserDefaults.standard.predictionAutoSelectAlgorithm
        case .autoSelectPredictionAlgorithm:
            // Only enabled if predictions are on
            return UserDefaults.standard.predictionEnabled
        case .includeTreatmentsInPredictions:
            // Only enabled if predictions are on
            return UserDefaults.standard.predictionEnabled
        case .insulinSensitivityFactor, .carbRatio, .insulinType, .carbAbsorptionRate, .carbAbsorptionDelay:
            // Only enabled if predictions are on AND treatments are included
            return UserDefaults.standard.predictionEnabled && UserDefaults.standard.predictionIncludeTreatments
        default:
            return true
        }
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentHighValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentHighMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentHighMarkValue:String) in UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded = urgentHighMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .highMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelHighValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.highMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultHighMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(highMarkValue:String) in UserDefaults.standard.highMarkValueInUserChosenUnitRounded = highMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .targetMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTargetValue, message: Texts_SettingsView.targetValueMessage, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.targetMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultTargetMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(targetMarkValue:String) in UserDefaults.standard.targetMarkValueInUserChosenUnitRounded = targetMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .lowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.lowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(lowMarkValue:String) in UserDefaults.standard.lowMarkValueInUserChosenUnitRounded = lowMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .urgentLowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentLowMarkValue:String) in UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded = urgentLowMarkValue}, cancelHandler: nil, inputValidator: nil)
            
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
            
        case .showPredictions:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.predictionEnabled {
                    UserDefaults.standard.predictionEnabled = false
                } else {
                    UserDefaults.standard.predictionEnabled = true
                }
            })
            
        case .autoSelectPredictionAlgorithm:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.predictionAutoSelectAlgorithm {
                    UserDefaults.standard.predictionAutoSelectAlgorithm = false
                } else {
                    UserDefaults.standard.predictionAutoSelectAlgorithm = true
                }
            })
            
        case .selectPredictionAlgorithm:
            
            // create list of algorithms
            var data = [String]()
            var selectedRow = 0
            
            for (index, algorithmType) in PredictionModelType.allCases.enumerated() {
                data.append(algorithmType.displayName)
                if algorithmType == UserDefaults.standard.predictionAlgorithmType {
                    selectedRow = index
                }
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.selectPredictionAlgorithm, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                if index != selectedRow {
                    UserDefaults.standard.predictionAlgorithmType = PredictionModelType.allCases[index]
                    
                    // Mark predictions for update
                    UserDefaults.standard.predictionsUpdateNeeded = true
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .includeTreatmentsInPredictions:
            return SettingsSelectedRowAction.callFunction(function: { [weak self] in
                if UserDefaults.standard.predictionIncludeTreatments {
                    UserDefaults.standard.predictionIncludeTreatments = false
                } else {
                    UserDefaults.standard.predictionIncludeTreatments = true
                }
                // reload section to update enabled states of dependent rows
                self?.sectionReloadClosure?()
            })
            
        case .insulinSensitivityFactor:
            // Get current value and convert to display units
            let currentValue = UserDefaults.standard.insulinSensitivityMgDl
            let displayValue = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? currentValue : currentValue.mgDlToMmol()
            let unitString = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
            
            return SettingsSelectedRowAction.askText(
                title: Texts_SettingsView.insulinSensitivityFactor,
                message: String(format: Texts_SettingsView.insulinSensitivityFactorMessage, unitString),
                keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad : .decimalPad,
                text: displayValue.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl),
                placeHolder: nil,
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: {(valueAsString: String) in
                    if let value = Double(valueAsString) {
                        // Convert to mg/dL for storage
                        let valueInMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? value : value.mmolToMgdl()
                        UserDefaults.standard.insulinSensitivityMgDl = valueInMgDl
                    }
                },
                cancelHandler: nil,
                inputValidator: nil
            )
            
        case .carbRatio:
            return SettingsSelectedRowAction.askText(
                title: Texts_SettingsView.carbRatio,
                message: Texts_SettingsView.carbRatioMessage,
                keyboardType: .decimalPad,
                text: UserDefaults.standard.carbRatio.stringWithoutTrailingZeroes,
                placeHolder: nil,
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: {(valueAsString: String) in
                    if let value = Double(valueAsString), value > 0 {
                        UserDefaults.standard.carbRatio = value
                    }
                },
                cancelHandler: nil,
                inputValidator: nil
            )
            
        case .insulinType:
            // Create list of insulin types
            var data = [String]()
            var selectedRow = 0
            
            for (index, insulinType) in InsulinType.allCases.enumerated() {
                data.append(insulinType.displayName)
                if insulinType == UserDefaults.standard.insulinType {
                    selectedRow = index
                }
            }
            
            return SettingsSelectedRowAction.selectFromList(
                title: Texts_SettingsView.insulinType,
                data: data,
                selectedRow: selectedRow,
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: {(index: Int) in
                    if index != selectedRow {
                        UserDefaults.standard.insulinType = InsulinType.allCases[index]
                    }
                },
                cancelHandler: nil,
                didSelectRowHandler: nil
            )
            
        case .carbAbsorptionRate:
            return SettingsSelectedRowAction.askText(
                title: Texts_SettingsView.carbAbsorptionRate,
                message: Texts_SettingsView.carbAbsorptionRateMessage,
                keyboardType: .decimalPad,
                text: UserDefaults.standard.carbAbsorptionRate.stringWithoutTrailingZeroes,
                placeHolder: nil,
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: {(valueAsString: String) in
                    if let value = Double(valueAsString), value > 0 {
                        UserDefaults.standard.carbAbsorptionRate = value
                    }
                },
                cancelHandler: nil,
                inputValidator: nil
            )
            
        case .carbAbsorptionDelay:
            return SettingsSelectedRowAction.askText(
                title: Texts_SettingsView.carbAbsorptionDelay,
                message: Texts_SettingsView.carbAbsorptionDelayMessage,
                keyboardType: .numberPad,
                text: Int(UserDefaults.standard.carbAbsorptionDelay).description,
                placeHolder: nil,
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: {(valueAsString: String) in
                    if let value = Double(valueAsString), value >= 0 {
                        UserDefaults.standard.carbAbsorptionDelay = value
                    }
                },
                cancelHandler: nil,
                inputValidator: nil
            )
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.homeScreenSettingsIcon + " " + Texts_SettingsView.sectionTitleHomeScreen
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
            
        case .urgentHighMarkValue:
            return "🔴 " + Texts_SettingsView.labelUrgentHighValue
            
        case .highMarkValue:
            return "🟡 " + Texts_SettingsView.labelHighValue
            
        case .targetMarkValue:
            return "🟢 " + Texts_SettingsView.labelTargetValue
            
        case .lowMarkValue:
            return "🟡 " + Texts_SettingsView.labelLowValue
            
        case .urgentLowMarkValue:
            return "🔴 " + Texts_SettingsView.labelUrgentLowValue
            
        case .showPredictions:
            return Texts_SettingsView.showPredictions
            
        case .autoSelectPredictionAlgorithm:
            return Texts_SettingsView.autoSelectPredictionAlgorithm
            
        case .selectPredictionAlgorithm:
            return Texts_SettingsView.selectPredictionAlgorithm
            
        case .includeTreatmentsInPredictions:
            return Texts_SettingsView.includeTreatmentsInPredictions
            
        case .insulinSensitivityFactor:
            return Texts_SettingsView.insulinSensitivityFactor
            
        case .carbRatio:
            return Texts_SettingsView.carbRatio
            
        case .insulinType:
            return Texts_SettingsView.insulinType
            
        case .carbAbsorptionRate:
            return Texts_SettingsView.carbAbsorptionRate
            
        case .carbAbsorptionDelay:
            return Texts_SettingsView.carbAbsorptionDelay
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .screenLockDimmingType, .urgentHighMarkValue, .highMarkValue, .lowMarkValue, .urgentLowMarkValue, .targetMarkValue, .selectPredictionAlgorithm, .insulinSensitivityFactor, .carbRatio, .insulinType, .carbAbsorptionRate, .carbAbsorptionDelay:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .allowScreenRotation, .showClockWhenScreenIsLocked, .showMiniChart, .showPredictions, .autoSelectPredictionAlgorithm, .includeTreatmentsInPredictions:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .highMarkValue:
            return UserDefaults.standard.highMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .targetMarkValue:
            return UserDefaults.standard.targetMarkValueInUserChosenUnit == 0 ? Texts_Common.disabled : UserDefaults.standard.targetMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .lowMarkValue:
            return UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .urgentLowMarkValue:
            return UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .screenLockDimmingType:
            return UserDefaults.standard.screenLockDimmingType.description
            
        case .selectPredictionAlgorithm:
            if UserDefaults.standard.predictionAutoSelectAlgorithm {
                return Texts_SettingsView.automatic
            } else {
                return UserDefaults.standard.predictionAlgorithmType.displayName
            }
            
        case .insulinSensitivityFactor:
            let value = UserDefaults.standard.insulinSensitivityMgDl
            let displayValue = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? value : value.mgDlToMmol()
            return displayValue.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + (UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
            
        case .carbRatio:
            return UserDefaults.standard.carbRatio.stringWithoutTrailingZeroes + " " + Texts_Common.grams
            
        case .insulinType:
            return UserDefaults.standard.insulinType.displayName
            
        case .carbAbsorptionRate:
            return UserDefaults.standard.carbAbsorptionRate.stringWithoutTrailingZeroes + " " + Texts_SettingsView.gramsPerHour
            
        case .carbAbsorptionDelay:
            return Int(UserDefaults.standard.carbAbsorptionDelay).description + " " + Texts_Common.minutes
            
        case .allowScreenRotation, .showClockWhenScreenIsLocked, .showMiniChart, .showPredictions, .autoSelectPredictionAlgorithm, .includeTreatmentsInPredictions:
            return nil
            
        }
    }
    
}
