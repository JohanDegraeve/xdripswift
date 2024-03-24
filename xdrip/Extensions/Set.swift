//
//  Set.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

extension Set {
    static var all: Set<Days> {
        return [7, 14, 30, 90, 0]
    }
    
    static var allExceptToday: Set<Days> {
        return [7, 14, 30, 90]
    }
    
    static var none: Set<Days> {
        return []
    }
}
