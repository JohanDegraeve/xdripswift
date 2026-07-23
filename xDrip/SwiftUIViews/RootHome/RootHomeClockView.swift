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

    var body: some View {
        Text(text)
            .font(.system(size: 120))
            .foregroundStyle(ConstantsAppColors.clockText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}
