//
//  SettingsViewInsulinOnBoardModel.swift
//  xdrip
//
//  Created by Eduardo Pietre on 28/06/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit


/// Enum used for each row of InsulinOnBoardSettings.
fileprivate enum Setting: Int, CaseIterable {
	
	/// Should the label be enabled?
	case toggleDisplay = 0
	
	/// Draw on chart?
	case showIOBOnChart = 1
	
	/// Insulin Activity Duration in minutes
	case insulinActivityDuration = 2
	
	/// Insulin Peak time in minutes
	case insulinPeakTime = 3
	
}


/// SettingsViewInsulinOnBoardModel defines the settings section for IOB stuff.
/// Implements SettingsViewModelProtocol.
struct SettingsViewInsulinOnBoardModel: SettingsViewModelProtocol {
	
	func sectionTitle() -> String? {
		return Texts_SettingsView.sectionTitleInsulinOnBoard;
	}
	
	func settingsRowText(index: Int) -> String {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
			
		case .toggleDisplay:
			return Texts_SettingsView.sectionTitleInsulinOnBoardToggleDisplay
		case .showIOBOnChart:
			return Texts_SettingsView.sectionTitleInsulinOnBoardShowIOBOnChart
		case .insulinActivityDuration:
			return Texts_SettingsView.sectionTitleInsulinOnBoardInsulinActivityDuration
		case .insulinPeakTime:
			return Texts_SettingsView.sectionTitleInsulinOnBoardInsulinPeakTime
			
		}
	}
	
	func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
		case .toggleDisplay, .showIOBOnChart:
			return UITableViewCell.AccessoryType.none
		case .insulinActivityDuration, .insulinPeakTime:
			return UITableViewCell.AccessoryType.disclosureIndicator
		}
	}
	
	func detailedText(index: Int) -> String? {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
		case .toggleDisplay, .showIOBOnChart:
			return nil
		case .insulinActivityDuration:
			return UserDefaults.standard.insulinOnBoardInsulinActivityDuration.description
		case .insulinPeakTime:
			return UserDefaults.standard.insulinOnBoardInsulinPeakTime.description
		}
	}
	
	func uiView(index: Int) -> UIView? {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
		case .toggleDisplay:
			return UISwitch(isOn: UserDefaults.standard.insulinOnBoardEnabledDisplay, action: {(isOn:Bool) in UserDefaults.standard.insulinOnBoardEnabledDisplay = isOn})
		case .showIOBOnChart:
			return UISwitch(isOn: UserDefaults.standard.insulinOnBoardShowOnChart, action: {(isOn:Bool) in UserDefaults.standard.insulinOnBoardShowOnChart = isOn})
		case .insulinActivityDuration:
			return nil
		case .insulinPeakTime:
			return nil
		}
	}
	
	func numberOfRows() -> Int {
		return Setting.allCases.count
	}
	
	func onRowSelect(index: Int) -> SettingsSelectedRowAction {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
		case .toggleDisplay:
			return SettingsSelectedRowAction.callFunction(function: {
				UserDefaults.standard.insulinOnBoardEnabledDisplay = !UserDefaults.standard.insulinOnBoardEnabledDisplay
			})
		case .showIOBOnChart:
			return SettingsSelectedRowAction.callFunction(function: {
				UserDefaults.standard.insulinOnBoardShowOnChart = !UserDefaults.standard.insulinOnBoardShowOnChart
			})
		case .insulinActivityDuration:
			return SettingsSelectedRowAction.askText(title: Texts_SettingsView.sectionTitleInsulinOnBoardInsulinActivityDuration, message: Texts_SettingsView.sectionTitleInsulinOnBoardInsulinActivityDurationMessage, keyboardType: .numberPad, text: UserDefaults.standard.insulinOnBoardInsulinActivityDuration.description, placeHolder: "180", actionTitle: nil, cancelTitle: nil, actionHandler: {(threshold:String) in if let threshold = Int(threshold) {UserDefaults.standard.insulinOnBoardInsulinActivityDuration = Int(threshold)}}, cancelHandler: nil, inputValidator: nil)
		case .insulinPeakTime:
			return SettingsSelectedRowAction.askText(title: Texts_SettingsView.sectionTitleInsulinOnBoardInsulinPeakTime, message: Texts_SettingsView.sectionTitleInsulinOnBoardInsulinPeakTimeMessage, keyboardType: .numberPad, text: UserDefaults.standard.insulinOnBoardInsulinPeakTime.description, placeHolder: "0", actionTitle: nil, cancelTitle: nil, actionHandler: {(threshold:String) in if let threshold = Int(threshold) {UserDefaults.standard.insulinOnBoardInsulinPeakTime = Int(threshold)}}, cancelHandler: nil, inputValidator: nil)
		}
	}
	
	func isEnabled(index: Int) -> Bool {
		return true
	}
	
	func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
		return false
	}
	
	func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
		// this ViewModel does need to send back messages to the viewcontroller asynchronously
	}
	
	func storeUIViewController(uIViewController: UIViewController) {
	}
	
	func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {
	}
	
}

