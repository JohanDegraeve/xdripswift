//
//  SensorNoiseIndicatorView.swift
//  xdrip
//
//  Created by Paul Plant on 26/11/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// A scalable sensor noise mark with two quiet rings around its status dot.
/// The size is the outer diameter, and the center and rings scale proportionally.
struct SensorNoiseIndicatorView: View {
    let color: Color
    let size: CGFloat

    private var centerSize: CGFloat { size * 0.44 }
    private var innerRingSize: CGFloat { size * 0.72 }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(color.opacity(0.25), lineWidth: size * 0.075)

            Circle()
                .strokeBorder(color.opacity(0.42), lineWidth: size * 0.11)
                .frame(width: innerRingSize, height: innerRingSize)

            Circle()
                .fill(color)
                .frame(width: centerSize, height: centerSize)
        }
        .frame(width: size, height: size)
    }
}
