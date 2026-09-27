//
//  SheetCloseButton.swift
//  xdrip
//
//  Created by Paul Plant on 27/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Dismisses a sheet without discarding unsubmitted work. Editors should use Cancel instead.
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(role: .close, action: action)
            } else {
                Button(action: action) {
                    Label(Texts_Common.close, systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
        .accessibilityLabel(Texts_Common.close)
    }
}
