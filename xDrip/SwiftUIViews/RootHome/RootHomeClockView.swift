//
//  RootHomeClockView.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Large clock used by the locked night layout.
struct RootHomeClockView: View {
    let text: String

    private enum Layout {
        // Start deliberately large so minimumScaleFactor fits the localized time to the full width.
        static let fontSize: CGFloat = 500
    }

    var body: some View {
        Text(text)
            .font(.system(size: Layout.fontSize, weight: .bold))
            .foregroundStyle(ConstantsAppColors.clockText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.01)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}
