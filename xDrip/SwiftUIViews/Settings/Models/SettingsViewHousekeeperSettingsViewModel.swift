//
//  SettingsViewHousekeeperSettingsViewModel.swift
//  xdrip
//
//  Created by Eduardo Pietre on 07/05/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation
import os


/// Enum used for each row of HousekeeperSettings.
fileprivate enum Setting: Int, CaseIterable {
	
	/// For how many days should we store BgReadings, Calibrations and Treatments, in days
	case housekeeperRetentionPeriod = 0
	
}


/// SettingsViewHousekeeperSettingsViewModel defines the settings section for Housekeeper.
/// Implements SettingsViewModelProtocol.
struct SettingsViewHousekeeperSettingsViewModel: SettingsViewModelProtocol {

	// MARK: - Native SwiftUI rows

	func settingsRows(sectionID _: Int) -> [SettingsRow] {
		[
			SettingsRow(
                id: "housekeeper.retentionPeriod",
                title: Texts_SettingsView.settingsviews_housekeeperRetentionPeriod,
                detail: UserDefaults.standard.retentionPeriodInDays.description + " " + Texts_Common.days,
                action: .selectionList(retentionSelectionList)
            )
		]
	}

    init(coreDataManager _: CoreDataManager?) {}
	
	func sectionTitle() -> String? {
		return Texts_SettingsView.sectionTitleHousekeeper;
	}
	
	func settingsRowText(index: Int) -> String {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
			
		case .housekeeperRetentionPeriod:
			return Texts_SettingsView.settingsviews_housekeeperRetentionPeriod
			
		}
	}
	
	func accessoryType(index: Int) -> SettingsAccessory {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {

		case .housekeeperRetentionPeriod:
			return SettingsAccessory.disclosure
			
		}
	}
	
	func detailedText(index: Int) -> String? {
		guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
		
		switch setting {
			
		case .housekeeperRetentionPeriod:
			return UserDefaults.standard.retentionPeriodInDays.description + " " + Texts_Common.days
			
		}
	}
	
	
	func numberOfRows() -> Int {
		return Setting.allCases.count
	}

	func onRowSelect(index _: Int) -> SettingsSelectedRowAction {
		SettingsSelectedRowAction.nothing
	}

    /// Uses the same fixed blocks as automatic housekeeping and Nightscout import.
    private func retentionSelectionList() -> SettingsSelectionListContent {
        let periods = ConstantsHousekeeping.retentionPeriodsInDays
        let current = UserDefaults.standard.retentionPeriodInDays
        return SettingsSelectionListContent(
            title: Texts_SettingsView.settingsviews_housekeeperRetentionPeriod,
            data: periods.map { $0.description + " " + Texts_Common.days },
            selectedRow: periods.firstIndex(of: current),
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            action: { index in
                guard periods.indices.contains(index) else { return }
                UserDefaults.standard.retentionPeriodInDays = periods[index]
                trace(
                    "in housekeeper retention selection, retention period = %{public}@ days",
                    log: OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement),
                    category: ConstantsLog.categoryDataManagement,
                    type: .info,
                    periods[index].description
                )
            },
            cancel: nil,
            didSelectRow: nil
        )
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
	
	
	func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {
	}
	
}
