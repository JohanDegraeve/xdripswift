//
//  SettingsViewHousekeeperSettingsViewModel.swift
//  xdrip
//
//  Created by Eduardo Pietre on 07/05/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit


/// Enum used for each row of HousekeeperSettings.
fileprivate enum Setting: Int, CaseIterable {
	
	/// For how many days should we store BgReadings, Calibrations and Treatments, in days
	case housekeeperRetentionPeriod = 0
	
	/// Export all data button
	case exportAllData = 1
	
}


/// SettingsViewHousekeeperSettingsViewModel defines the settings section for Housekeeper.
/// Implements SettingsViewModelProtocol.
struct SettingsViewHousekeeperSettingsViewModel: SettingsViewModelProtocol {

	/// Instance of coreDataManager
	private var coreDataManager: CoreDataManager?
    
    init(coreDataManager: CoreDataManager?) {
        self.coreDataManager = coreDataManager
    }
	
	func sectionTitle() -> String? {
		return ConstantsSettingsIcons.housekeeperSettingsIcon + " " + Texts_SettingsView.sectionTitleHousekeeper;
	}
	
	func settingsRowText(index: Int) -> String {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
			
		case .housekeeperRetentionPeriod:
			return Texts_SettingsView.settingsviews_housekeeperRetentionPeriod
			
		case .exportAllData:
			return Texts_SettingsView.settingsviews_housekeeperExportAllData
			
		}
	}
	
	func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {

		case .housekeeperRetentionPeriod:
			return UITableViewCell.AccessoryType.disclosureIndicator
			
		case .exportAllData:
			return UITableViewCell.AccessoryType.none
			
		}
	}
	
	func detailedText(index: Int) -> String? {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
			
		case .housekeeperRetentionPeriod:
			return UserDefaults.standard.retentionPeriodInDays.description
			
		case .exportAllData:
			return nil

		}
	}
	
	func uiView(index: Int) -> UIView? {
		return nil
	}
	
	func numberOfRows() -> Int {
		return Setting.allCases.count
	}
	
	func onRowSelect(index: Int) -> SettingsSelectedRowAction {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
		
		// When housekeeperRetentionPeriod is selected, display a popup asking for the new retention period.
		case .housekeeperRetentionPeriod:
			return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_housekeeperRetentionPeriod, message: Texts_SettingsView.settingsviews_housekeeperRetentionPeriodMessage, keyboardType: .numberPad, text: UserDefaults.standard.retentionPeriodInDays.description, placeHolder: "90", actionTitle: nil, cancelTitle: nil, actionHandler: {
				(retention:String) in if let retentionInt = Int(retention) {UserDefaults.standard.retentionPeriodInDays = retentionInt}}, cancelHandler: nil, inputValidator: nil)
		
		// When exportAllData is selected, calls DataExporter for generating and writing the data to a file, passing the callback down to exportAllData.
		case .exportAllData:
			return SettingsSelectedRowAction.callFunctionAndShareFile { callback in
				// coreDataManager must not be nil.
				if let coreDataManager = coreDataManager {
					DataExporter(coreDataManager: coreDataManager, callback: callback).exportAllData()
				} else {
					// All routines MUST call callback
					callback(nil)
				}
			}
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

