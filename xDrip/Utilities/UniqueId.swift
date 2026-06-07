//
//  UniqueId.swift
//  xdrip
//
//  Created by Johan Degraeve on 08/12/2018.
//  Copyright © 2018 Johan Degraeve. All rights reserved.
//

import Foundation

/// static functions related to creation of identifiers
class UniqueId {
    
    ///no instances should be created
    private init() {}
    
    /// creates random string 24 charaacters a-z A-Z 0-9, default length 24
    static func createEventId(withLength length:Int? = 24) -> String {
        var lengthToUse = 24;
        if let length = length {
            lengthToUse = length
        }
        //source https://stackoverflow.com/questions/26845307/generate-random-alphanumeric-string-in-swift
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0...lengthToUse - 1).map { _ in letters.randomElement()! })}
}
