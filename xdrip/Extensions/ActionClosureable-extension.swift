//
//  ExtensionClosureable-extension.swift
//  xdrip
//
//  Created by Johan Degraeve on 04/03/2019.
//  Copyright © 2019 Johan Degraeve. All rights reserved.
//

import Foundation
import ActionClosurable

extension ActionClosurable where Self:UISwitch {
    func addTarget(_ target: Any?, action: @escaping (Self) -> Void, for controlEvents: UIControl.Event) {
        convert(closure: action, toConfiguration: {
            self.addTarget($0, action: $1, for: controlEvents)
        })
    }
}

