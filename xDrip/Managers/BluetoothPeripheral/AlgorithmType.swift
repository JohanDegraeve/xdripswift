//
//  AlgorithmType.swift
//  xdrip
//
//  Created by Paul Plant on 22/8/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// types of algorithms available to use
public enum AlgorithmType: Int, CaseIterable {
    case nativeAlgorithm = 0
    case xDripAlgorithm = 1
    
    var description: String {
        switch self {
        case .nativeAlgorithm:
            return Texts_BluetoothPeripheralView.nativeAlgorithm
        case .xDripAlgorithm:
            return Texts_BluetoothPeripheralView.xDripAlgorithm
        }
    }
    
}

