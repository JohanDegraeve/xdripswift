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
    
    /// This is the default colour for the time stamp view when it is the current, latest one.
    static let defaultTimeStampColour: UIColor = UIColor(red: 0.392, green: 0.827, blue: 0.933, alpha: 1.00)
    
    /// This returns the complementary colour of a `UIColour` by rotating the hue by 180 degrees
    var complimentary: UIColor {
        var h: CGFloat = 0.0, s: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        h += 0.5 // rotate the hue 180 degrees
        h -= (h > 1.0 ? 0.5 : 0.0) // normalise to  0.0 ... 1.0
        return UIColor(hue: h, saturation: s, brightness: b, alpha: a)
    }
}
