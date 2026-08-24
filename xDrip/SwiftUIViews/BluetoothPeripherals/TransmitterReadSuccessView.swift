//
//  TransmitterReadSuccessView.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Shows transmitter reliability totals and the hourly reading timeline.
struct TransmitterReadSuccessView: View {
    let display: TransmitterReadSuccessDisplay
    let bluetoothPeripheralType: BluetoothPeripheralType

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(percentText(display.success24h, decimalPlaces: 0))
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(color(for: display.success24h))
                            .lineLimit(1)

                        Spacer()

                        Text("24h")
                            .font(.headline)
                            .foregroundStyle(Color(.colorSecondary))
                    }

                    ProgressView(value: progressValue(actual: display.actual24h, expected: display.expected24h))
                        .progressViewStyle(.linear)
                        .tint(color(for: display.success24h))

                    Text(Texts_BluetoothPeripheralView.readSuccessReadingsReceived(actual: display.actual24h, expected: display.expected24h))
                        .font(.subheadline)
                        .foregroundStyle(Color(.colorSecondary))
                }
                .padding(.vertical, 4)
            } header: {
                Text(Texts_BluetoothPeripheralView.status)
                    .foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
            } footer: {
                Text(Texts_BluetoothPeripheralView.readSuccessCadenceFooter(bluetoothPeripheralType: bluetoothPeripheralType.bluetoothPeripheralDisplayTitle))
                    .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                    .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
            }

            Section {
                ReadSuccessTimelineView(buckets: display.hourlyBuckets, colorForSuccess: color)
                    .padding(.vertical, 6)
            } header: {
                Text(Texts_BluetoothPeripheralView.readSuccessLast24Hours)
                    .foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
            } footer: {
                HStack(spacing: 14) {
                    ReadSuccessLegendItem(color: .green, title: Texts_BluetoothPeripheralView.readSuccessLegendGood)
                    ReadSuccessLegendItem(color: Color(.systemYellow), title: Texts_BluetoothPeripheralView.readSuccessLegendLow)
                    ReadSuccessLegendItem(color: Color(.systemRed), title: Texts_BluetoothPeripheralView.readSuccessLegendPoor)
                    ReadSuccessLegendItem(color: Color(.systemGray), title: Texts_BluetoothPeripheralView.readSuccessLegendNoData)
                }
                .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(Texts_BluetoothPeripheralView.readSuccess)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
    }

    private func color(for successPercentage: Double) -> Color {
        let okSuccessPercentage = display.nominalGapInSeconds > 180 ? 95.0 : 80.0
        let warningSuccessPercentage = display.nominalGapInSeconds > 180 ? 90.0 : 70.0

        if successPercentage >= okSuccessPercentage {
            return .green
        } else if successPercentage >= warningSuccessPercentage {
            return Color(.systemYellow)
        } else {
            return Color(.systemRed)
        }
    }

    private func percentText(_ success: Double, decimalPlaces: Int) -> String {
        String(format: "%0.\(decimalPlaces)f%%", success)
    }

    private func progressValue(actual: Int, expected: Int) -> Double {
        guard expected > 0 else { return 0 }

        return min(max(Double(actual) / Double(expected), 0), 1)
    }
}

private struct ReadSuccessTimelineView: View {
    let buckets: [TransmitterReadSuccessHourlyBucket]
    let colorForSuccess: (Double) -> Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(buckets) { bucket in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: bucket))
                        .frame(maxWidth: .infinity)
                        .frame(height: height(for: bucket))
                        .accessibilityLabel(accessibilityText(for: bucket))
                }
            }
            .frame(height: 48)

            HStack {
                Text("24h")
                Spacer()
                Text("18h")
                Spacer()
                Text("12h")
                Spacer()
                Text("6h")
                Spacer()
                Text(Texts_BluetoothPeripheralView.readSuccessNow)
            }
            .font(.caption2)
            .foregroundStyle(Color(.colorTertiary))
        }
    }

    private func color(for bucket: TransmitterReadSuccessHourlyBucket) -> Color {
        guard bucket.expected > 0 else { return Color(.systemGray) }

        return colorForSuccess(bucket.success)
    }

    private func height(for bucket: TransmitterReadSuccessHourlyBucket) -> CGFloat {
        guard bucket.expected > 0 else { return 12 }

        return 20 + CGFloat(min(max(bucket.success / 100.0, 0), 1)) * 28
    }

    private func accessibilityText(for bucket: TransmitterReadSuccessHourlyBucket) -> String {
        guard bucket.expected > 0 else {
            return Texts_BluetoothPeripheralView.readSuccessNoReadingsExpected
        }

        return Texts_BluetoothPeripheralView.readSuccessTimelineAccessibility(success: bucket.success, actual: bucket.actual, expected: bucket.expected)
    }
}

private struct ReadSuccessLegendItem: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.caption)
        }
    }
}
