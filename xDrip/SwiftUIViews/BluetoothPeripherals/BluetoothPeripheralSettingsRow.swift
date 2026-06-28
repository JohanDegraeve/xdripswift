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
    let detailIndicator: SettingsIndicator?
    let detailSymbol: BluetoothPeripheralDetailSymbol?
    let showsDisclosure: Bool
    let isEnabled: Bool

    init(
        title: String,
        detail: String?,
        detailIndicator: SettingsIndicator? = nil,
        detailSymbol: BluetoothPeripheralDetailSymbol? = nil,
        showsDisclosure: Bool = false,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.detail = detail
        self.detailIndicator = detailIndicator
        self.detailSymbol = detailSymbol
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
                HStack(spacing: 5) {
                    if let detailIndicator {
                        Image(systemName: detailIndicator.symbolName)
                            .font(.caption2)
                            .foregroundStyle(isEnabled ? detailIndicator.color : .gray)
                            .accessibilityLabel(detailIndicator.accessibilityLabel ?? "")
                    }

                    if let detailSymbol {
                        Image(systemName: detailSymbol.systemName)
                            .foregroundStyle(isEnabled ? detailSymbol.color : .gray)
                            .imageScale(.medium)
                    }

                    Text(detail)
                        .foregroundStyle(isEnabled ? Color(.colorSecondary) : Color.gray)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.colorTertiary))
            }
        }
    }
}
