//
//  UIColor.swift
//  xdrip
//
//  Created by Todd Dalton on 03/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

// Used to make `UIColor` Codable
extension UIColor {
    
    /// Returns the RGBA components of a `UIColor` as `Data` so that the colour can be stored in `UserDefaults`
    ///
    /// Returns `nil` if the API was unable to encode the colour into `JSON`
    var RGBA: Data? {
        var components: UIColor.RGBComps = RGBComps()
        
        getRed(&components.r, green: &components.g, blue: &components.b, alpha: &components.a)
        
        let json = JSONEncoder()
        
        do {
            return try json.encode(
                ["red" : components.r,
                 "green" : components.g,
                 "blue" : components.b,
                 "alpha" : components.a]
            )
        } catch let e {
            dump(e.localizedDescription)
        }
        return nil
    }
    
    /// Reconstructs a `UIColor` from provided `Data`
    ///
    /// The `Data` should have been initially encoded as per the computed `RGBA` var.
    /// Returns `nil` if the API is unable to create a `UIColor` from the received `Data`
    static func makeUIColourFrom(_data: Data) -> UIColor? {
        let json = JSONDecoder()
        do {
            let comps = try json.decode(UIColor.RGBComps.self, from: _data)
            return UIColor(red: comps.r, green: comps.g, blue: comps.b, alpha: comps.a)
        } catch let e {
            print(e.localizedDescription)
        }
        return nil
    }
    
    public struct RGBComps: Codable {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
    }
}
