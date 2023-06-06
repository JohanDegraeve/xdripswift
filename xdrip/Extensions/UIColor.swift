//
//  UIColor.swift
//  xdrip
//
//  Created by Todd Dalton on 03/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

extension UIColor {
    
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
