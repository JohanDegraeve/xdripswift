//
//  TreatmentsInsertViewController.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

final class TreatmentsInsertViewController: PortraitLockedHostingController<AnyView> {
    // MARK: - private properties

    private let completionHandler: (() -> Void)?
    private let viewModel: TreatmentEditorViewModel

    @IBOutlet weak var titleNavigation: UINavigationItem?
    @IBOutlet weak var carbsLabel: UILabel?
    @IBOutlet weak var insulinLabel: UILabel?
    @IBOutlet weak var exerciseLabel: UILabel?
    @IBOutlet weak var basalRateLabel: UILabel?
    @IBOutlet weak var bgCheckLabel: UILabel?
    @IBOutlet weak var doneButton: UIBarButtonItem?
    @IBOutlet weak var datePicker: UIDatePicker?
    @IBOutlet weak var carbsTextField: UITextField?
    @IBOutlet weak var insulinTextField: UITextField?
    @IBOutlet weak var exerciseTextField: UITextField?
    @IBOutlet weak var basalRateTextField: UITextField?
    @IBOutlet weak var bgCheckTextField: UITextField?
    @IBOutlet weak var carbsUnitLabel: UILabel?
    @IBOutlet weak var insulinUnitLabel: UILabel?
    @IBOutlet weak var exerciseUnitLabel: UILabel?
    @IBOutlet weak var basalRateUnitLabel: UILabel?
    @IBOutlet weak var bgCheckUnitLabel: UILabel?
    @IBOutlet weak var carbsStackView: UIStackView?
    @IBOutlet weak var insulinStackView: UIStackView?
    @IBOutlet weak var exerciseStackView: UIStackView?
    @IBOutlet weak var basalRateStackView: UIStackView?
    @IBOutlet weak var bgCheckStackView: UIStackView?
    @IBOutlet weak var enteredByStackView: UIStackView?
    @IBOutlet weak var enteredByLabel: UILabel?
    @IBOutlet weak var enteredByValue: UILabel?

    // MARK: - initialization

    init(coreDataManager: CoreDataManager, treatmentToEdit: TreatmentEntry?, completionHandler: (() -> Void)? = nil) {
        self.viewModel = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: treatmentToEdit)
        self.completionHandler = completionHandler

        let rootView = AnyView(
            TreatmentEditorView(
                viewModel: self.viewModel,
                onDelete: nil
            )
        )

        super.init(rootView: rootView)

        self.title = viewModel.navigationTitle
        self.rootView = AnyView(
            TreatmentEditorView(
                viewModel: self.viewModel,
                onDelete: { [weak self] in
                    self?.deleteTreatment()
                }
            )
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveButtonTapped))
        navigationItem.rightBarButtonItem?.tintColor = UIColor(resource: .colorPrimary)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        self.viewModel = TreatmentEditorViewModel(coreDataManager: nil, treatmentToEdit: nil)
        self.completionHandler = nil

        super.init(coder: aDecoder, rootView: AnyView(EmptyView()))
    }

    // MARK: - private functions

    @objc private func saveButtonTapped() {
        guard viewModel.saveTreatment() else {
            return
        }

        completionHandler?()
        navigationController?.popViewController(animated: true)
    }

    private func deleteTreatment() {
        guard viewModel.deleteTreatment() else {
            return
        }

        completionHandler?()
        navigationController?.popViewController(animated: true)
    }

    @IBAction func doneButtonTapped(_ sender: UIBarButtonItem) {
    }
}
