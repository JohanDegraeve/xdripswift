//
//  View.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    /// Sets and returns the width of the widest child view so far.
    ///
    /// Placing this func on the end of a row of items means the items pass into `ViewWidthKey` their
    /// individual widths. If the current child is the widest, then it will perform the block `onChange`.
    /// https://www.fivestars.blog/articles/flexible-swiftui/
    func getItemWidth(onChange: @escaping (CGFloat) -> Void) -> some View {
        background( GeometryReader { geom in
            Color.clear.preference(key: ViewWidthKey.self, value: geom.size.width)
        }).onPreferenceChange(ViewWidthKey.self, perform: onChange)
    }
}
