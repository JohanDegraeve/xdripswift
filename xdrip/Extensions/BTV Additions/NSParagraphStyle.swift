//
//  NSParagraphStyle.swift
//  xdrip
//
//  Created by Todd Dalton on 03/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

extension NSParagraphStyle {
    static func centredText() -> NSParagraphStyle {
        let _style = NSMutableParagraphStyle()
        _style.alignment = .center
        return _style
    }
    static func rightJustifiedText() -> NSParagraphStyle {
        let _style = NSMutableParagraphStyle()
        _style.alignment = .right
        return _style
    }
    static func leftJustified() -> NSParagraphStyle {
        let _style = NSMutableParagraphStyle()
        _style.alignment = .left
        return _style
    }
}
