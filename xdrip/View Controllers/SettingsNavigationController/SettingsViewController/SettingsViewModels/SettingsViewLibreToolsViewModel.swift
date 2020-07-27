//
//  SettingsViewLibreToolsViewModel.swift
//  xdrip
//
//  Created by Ivan Valkou on 24.07.2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import UIKit
import LibreTools

fileprivate enum Setting:Int, CaseIterable {
    case libreTools = 0
}

struct SettingsViewLibreToolsViewModel: SettingsViewModelProtocol {
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}

    func storeUIViewController(uIViewController: UIViewController) {}

    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}

    func sectionTitle() -> String? { "Freestyle Libre" }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .libreTools:
            return "Libre tools"
        }
    }

    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .libreTools:
            return .disclosureIndicator
        }
    }

    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .libreTools:
            return nil
        }
    }

    func uiView(index: Int) -> UIView? { nil }

    func numberOfRows() -> Int { Setting.allCases.count }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .libreTools:
           if #available(iOS 13, *) {
                return .presentModal(viewController: LibreTools.makeViewController())
            }
            return .nothing
        }
    }

    func isEnabled(index: Int) -> Bool {
        if #available(iOS 13, *) {
            return true
        }
        return false
    }

    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
}

