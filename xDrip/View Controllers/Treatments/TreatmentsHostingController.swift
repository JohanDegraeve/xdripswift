//
//  TreatmentsHostingController.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

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
