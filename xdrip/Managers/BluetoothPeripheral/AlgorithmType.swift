//
//  AlgorithmType.swift
//  xdrip
//
//  Created by Paul Plant on 22/8/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// types of live activity, namely when we should show the live activities
public enum AlgorithmType: Int, CaseIterable {
    
    // when adding to LiveActivityType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    
    case transmitterAlgorithm = 0
    case xDripAlgorithm = 1
    
    var description: String {
        switch self {
        case .transmitterAlgorithm:
            return Texts_BluetoothPeripheralView.transmitterAlgorithm
        case .xDripAlgorithm:
            return Texts_BluetoothPeripheralView.xDripAlgorithm
        }
    }
    
}

