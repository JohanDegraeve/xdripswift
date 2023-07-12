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
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }
    static func rightJustifiedText() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }
    static func leftJustified() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        return style
    }
}
