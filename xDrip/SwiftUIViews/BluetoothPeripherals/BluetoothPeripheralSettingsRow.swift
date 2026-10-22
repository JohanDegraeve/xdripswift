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
    let detailLineLimit: Int
    let showsDisclosure: Bool
    let isEnabled: Bool

    init(
        title: String,
        detail: String?,
        detailIndicator: SettingsIndicator? = nil,
        detailSymbol: BluetoothPeripheralDetailSymbol? = nil,
        detailLineLimit: Int = 2,
        showsDisclosure: Bool = false,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.detail = detail
        self.detailIndicator = detailIndicator
        self.detailSymbol = detailSymbol
        self.detailLineLimit = detailLineLimit
        self.showsDisclosure = showsDisclosure
        self.isEnabled = isEnabled
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(isEnabled ? ConstantsAppColors.rowTitleText : ConstantsAppColors.disabledText)
                .lineLimit(2)

            Spacer(minLength: 0)

            if let detail = detail, !detail.isEmpty {
                HStack(spacing: 5) {
                    if let detailIndicator {
                        SettingsIndicatorView(indicator: detailIndicator, isEnabled: isEnabled)
                    }

                    if let detailSymbol, !detailSymbol.isTrailing {
                        Image(systemName: detailSymbol.systemName)
                            .foregroundStyle(isEnabled ? detailSymbol.color : .gray)
                            .imageScale(.medium)
                    }

                    Text(detail)
                        .foregroundStyle(isEnabled ? ConstantsAppColors.rowDetailText : ConstantsAppColors.disabledText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(detailLineLimit)
                        .truncationMode(.tail)

                    if let detailSymbol, detailSymbol.isTrailing {
                        Image(systemName: detailSymbol.systemName)
                            .foregroundStyle(isEnabled ? detailSymbol.color : .gray)
                            .imageScale(.medium)
                    }
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
