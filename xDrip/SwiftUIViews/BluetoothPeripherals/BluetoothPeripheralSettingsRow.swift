//
//  BluetoothPeripheralSettingsRow.swift
//  xdrip
//
//  Created by Paul Plant on 19/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct BluetoothPeripheralSettingsRow: View {
    let title: String
    let detail: String?
    let showsDisclosure: Bool
    let isEnabled: Bool

    init(title: String, detail: String?, showsDisclosure: Bool = false, isEnabled: Bool = true) {
        self.title = title
        self.detail = detail
        self.showsDisclosure = showsDisclosure
        self.isEnabled = isEnabled
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(isEnabled ? Color(.colorPrimary) : Color.gray)
                .lineLimit(2)

            Spacer(minLength: 12)

            if let detail = detail, !detail.isEmpty {
                Text(detail)
                    .foregroundStyle(isEnabled ? Color(.colorSecondary) : Color.gray)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.colorTertiary))
            }
        }
    }
}
