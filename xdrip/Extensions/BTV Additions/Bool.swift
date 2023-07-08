//
//  Bool.swift
//  xdrip
//
//  Created by Todd Dalton on 22/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation


// It's a possibility that, technicaly, a True can be any number except zero
// This extension returns a very definite 1 or 0 depending on the Bool
// Probably not entirely necessary but unless it affects perfomance too badly
// it feels more secure to have a definite, numerical value
extension Bool {
    
    /// For D.R.Y. and readability.
    ///
    /// Returns an `Int` of `0` if `false` or `1` if `true`
    var rawIntValue: Int {
        return self ? 1 : 0
    }
    
    /// For D.R.Y. and readability.
    ///
    /// Returns a `Double` of `0.0` if `false` or `1.0` if `true`
    var rawDoubleValue: Double {
        return self ? 1.0 : 0.0
    }
    
    /// For D.R.Y. and readability.
    ///
    /// Returns a `Float` of `0.0` if `false` or `1.0` if `true`
    var rawFloatValue: Float {
        return self ? 1.0 : 0.0
    }
    
    /// For D.R.Y. and readability.
    ///
    /// Returns a `CGFloat` of `0.0` if `false` or `1.0` if `true`
    var rawCGFloatValue: CGFloat {
        return self ? 1.0 : 0.0
    }
}
