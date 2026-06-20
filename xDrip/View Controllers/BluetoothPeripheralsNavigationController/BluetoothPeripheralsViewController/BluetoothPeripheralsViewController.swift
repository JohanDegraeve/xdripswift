//
//  BluetoothPeripheralsViewController.swift
//  xdrip
//
//  Created by Johan Degraeve on 13/11/2019.
//  Copyright © 2019-2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

/// Retained only because the storyboard still creates this initial child before SwiftUI is installed.
final class BluetoothPeripheralsViewController: UIViewController {}

final class BluetoothPeripheralsHostingController: PortraitLockedHostingController<AnyView> {
    private let router: BluetoothPeripheralsRouter
    private let viewModel: BluetoothPeripheralsViewModel
    private let coreDataManager: CoreDataManager
    private let bluetoothPeripheralManager: BluetoothPeripheralManaging
    private weak var sensorProvider: ActiveSensorProviding?

    init(
        coreDataManager: CoreDataManager,
        bluetoothPeripheralManager: BluetoothPeripheralManaging,
        sensorProvider: ActiveSensorProviding?
    ) {
        let router = BluetoothPeripheralsRouter()
        let viewModel = BluetoothPeripheralsViewModel(bluetoothPeripheralManager: bluetoothPeripheralManager)

        self.router = router
        self.viewModel = viewModel
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.sensorProvider = sensorProvider

        super.init(rootView: AnyView(BluetoothPeripheralsView(viewModel: viewModel, router: router)))

        title = Texts_BluetoothPeripheralsView.screenTitle
        navigationItem.largeTitleDisplayMode = .automatic

        configureRouter()
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel.initializeBluetoothTransmitterDelegates()
        viewModel.reload()
    }

    func update(sensorProvider: ActiveSensorProviding?) {
        self.sensorProvider = sensorProvider
    }
}

private extension BluetoothPeripheralsHostingController {
    func configureRouter() {
        router.openPeripheral = { [weak self] bluetoothPeripheral, bluetoothPeripheralType in
            self?.open(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralType: bluetoothPeripheralType)
        }

        router.showAddPeripheralCategories = { [weak self] in
            self?.showAddPeripheralCategories()
        }

        router.showPeripheralTypes = { [weak self] category in
            self?.showPeripheralTypes(category: category)
        }
    }

    func open(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralType: BluetoothPeripheralType) {
        let detailState = BluetoothPeripheralDetailState(
            bluetoothPeripheral: bluetoothPeripheral,
            expectedBluetoothPeripheralType: bluetoothPeripheralType,
            coreDataManager: coreDataManager,
            bluetoothPeripheralManager: bluetoothPeripheralManager,
            sensorProvider: sensorProvider,
            closeDetailView: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
            presentTextEntryView: { [weak self] textEntry in
                self?.show(textEntry: textEntry)
            },
            presentSelectionListView: { [weak self] selectionList in
                self?.show(selectionList: selectionList)
            }
        )

        let viewController = PortraitLockedHostingController(
            rootView: BluetoothPeripheralDetailView(state: detailState)
        )
        viewController.title = detailState.screenTitle
        viewController.navigationItem.largeTitleDisplayMode = .automatic

        navigationController?.pushViewController(viewController, animated: true)
    }

    func showAddPeripheralCategories() {
        let viewController = PortraitLockedHostingController(
            rootView: AnyView(BluetoothPeripheralCategorySelectionView(
                viewModel: viewModel,
                router: router
            ))
        )
        viewController.title = Texts_BluetoothPeripheralsView.selectCategory
        viewController.navigationItem.largeTitleDisplayMode = .automatic

        navigationController?.pushViewController(viewController, animated: true)
    }

    func showPeripheralTypes(category: BluetoothPeripheralCategory) {
        let viewController = PortraitLockedHostingController(
            rootView: AnyView(BluetoothPeripheralTypeSelectionView(
                category: category,
                viewModel: viewModel,
                router: router
            ))
        )
        viewController.title = category.rawValue
        viewController.navigationItem.largeTitleDisplayMode = .automatic

        navigationController?.pushViewController(viewController, animated: true)
    }

    func show(textEntry: BluetoothPeripheralTextEntry) {
        let viewController = PortraitLockedHostingController(
            rootView: BluetoothPeripheralTextEntryView(textEntry: textEntry) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        )
        viewController.title = textEntry.title
        viewController.navigationItem.largeTitleDisplayMode = .automatic

        navigationController?.pushViewController(viewController, animated: true)
    }

    func show(selectionList: BluetoothPeripheralSelectionList) {
        let viewController = PortraitLockedHostingController(
            rootView: BluetoothPeripheralSelectionListView(selectionList: selectionList) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        )
        viewController.title = selectionList.title
        viewController.navigationItem.largeTitleDisplayMode = .automatic

        navigationController?.pushViewController(viewController, animated: true)
    }
}
