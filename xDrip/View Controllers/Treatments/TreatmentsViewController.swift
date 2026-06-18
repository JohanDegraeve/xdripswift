//
//  TreatmentsViewController.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

final class TreatmentsViewController: UIViewController {
    @IBOutlet weak var titleNavigation: UINavigationItem?
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var filterLabelOutlet: UILabel?
    @IBOutlet weak var filterSmallBolusButtonOutlet: UIButton?
    @IBOutlet weak var filterBolusButtonOutlet: UIButton?
    @IBOutlet weak var filterCarbsButtonOutlet: UIButton?
    @IBOutlet weak var filterBasalButtonOutlet: UIButton?

    @IBAction func filterSmallBolusButtonAction(_ sender: UIButton) {
    }

    @IBAction func filterBolusButtonAction(_ sender: UIButton) {
    }

    @IBAction func filterCarbsButtonAction(_ sender: UIButton) {
    }

    @IBAction func filterBasalButtonAction(_ sender: UIButton) {
    }
}

final class TreatmentsHostingController: PortraitLockedHostingController<AnyView> {
    init(coreDataManager: CoreDataManager) {
        let rootView = AnyView(TreatmentsView(coreDataManager: coreDataManager))

        super.init(rootView: rootView)

        self.title = Texts_TreatmentsView.treatmentsTitle
        navigationItem.largeTitleDisplayMode = .automatic
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
