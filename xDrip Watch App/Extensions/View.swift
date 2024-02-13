//
//  View.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 13/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct FitSystemFont: ViewModifier {
    var lineLimit: Int
    var minimumScaleFactor: CGFloat
    var percentage: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .font(.system(size: min(geometry.size.width, geometry.size.height) * percentage))
                .lineLimit(self.lineLimit)
                .minimumScaleFactor(self.minimumScaleFactor)
                .position(x: geometry.frame(in: .local).midX, y: geometry.frame(in: .local).midY)
        }
    }
}

extension View {
    func fitSystemFont(lineLimit: Int = 1, minimumScaleFactor: CGFloat = 0.01, percentage: CGFloat = 1) -> ModifiedContent<Self, FitSystemFont> {
        return modifier(FitSystemFont(lineLimit: lineLimit, minimumScaleFactor: minimumScaleFactor, percentage: percentage))
    }
}
