//
//  BluetoothSignalStrengthView.swift
//  xdrip
//
//  Created by Paul Plant on 11/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

/// A fresh, short-lived chart for finding a nearby Bluetooth device.
@MainActor
struct BluetoothSignalStrengthView: View {
    // Dim only the unobserved parts of an always-on device's gauge.
    // Keep colour and opacity independent so shading can be tuned without changing the signal palette.
    private static let gaugeHeight: CGFloat = 16
    private static let rangeOverlayColor = Color.black
    private static let rangeOverlayOpacity = 0.25

    let peripheral: BluetoothPeripheral
    let manager: BluetoothPeripheralManaging

    @Environment(\.scenePhase) private var scenePhase
    @State private var gaugeScale = BluetoothSignalStrengthGauge()
    @State private var history = BluetoothSignalStrengthHistory()
    @State private var sample: BluetoothSignalStrength?
    @State private var now = Date()
    @State private var visible = false
    @State private var connected = false
    @ScaledMetric(relativeTo: .largeTitle) private var strengthValueHeight = 41.0

    private var showsHistory: Bool { !peripheral.bluetoothPeripheralType().usesIntermittentConnection }

    private var transmitter: BluetoothTransmitter? {
        manager.getBluetoothTransmitter(for: peripheral, createANewOneIfNecesssary: false)
    }

    private var showsDisconnected: Bool { showsHistory && !connected }

    private var connectionStatus: BluetoothPeripheralDisplayStatus {
        BluetoothPeripheralDisplayStatus(
            isConnected: connected,
            isEnabled: peripheral.blePeripheral.shouldconnect,
            hasConnectedSinceActivation: peripheral.blePeripheral.hasConnectedSinceActivation,
            usesIntermittentConnection: !showsHistory
        )
    }


    private var signalColor: Color {
        if showsDisconnected { return ConstantsAppColors.secondaryText }
        guard let sample, sample.isCurrent(now: now) else { return ConstantsAppColors.secondaryText }
        return sample.band.color
    }

    private var timeDomain: ClosedRange<Date> { now.addingTimeInterval(-120)...now }

    private var signalDomain: ClosedRange<Int> {
        let values = history.points.map(\.sample.rssi)
        let range = BluetoothSignalStrength.displayRange
        return min(range.lowerBound, values.min() ?? range.lowerBound)...max(range.upperBound, values.max() ?? range.upperBound)
    }

    var body: some View {
        GeometryReader { geometry in
            List {
                Section {
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: connectionStatus.antennaSystemImage)
                                .foregroundStyle(connectionStatus.tintColor)
                                .accessibilityLabel(connectionStatus.fullStatusText)
                            Text(peripheral.blePeripheral.name)
                        }
                        .font(.headline)
                        Text(showsDisconnected ? Texts_BluetoothPeripheralView.signalStrengthDisconnected :
                             sample.map { "\($0.rssi) dBm" } ?? Texts_BluetoothPeripheralView.waiting)
                            .font(.largeTitle.bold().monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(height: strengthValueHeight)
                            .foregroundStyle(signalColor)
                        gauge.padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                if !showsHistory {
                    Section {
                        HStack {
                            Text(Texts_BluetoothPeripheralView.signalStrengthLastMeasurement)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .accessibilityHidden(true)
                                if let sample {
                                    Text(sample.measuredAt, style: .timer)
                                        .monospacedDigit()
                                } else {
                                    Text(Texts_BluetoothPeripheralView.waiting)
                                }
                            }
                            .foregroundStyle(Color(.colorSecondary))
                        }
                        .padding(.vertical, 3)
                    }
                }
                if showsHistory {
                    Section {
                        chart
                            .frame(height: max(120, min(180, geometry.size.height * 0.28)))
                            .listRowInsets(EdgeInsets(top: 16, leading: 8, bottom: 12, trailing: 12))
                    } footer: {
                        Text(Texts_BluetoothPeripheralView.signalStrengthChartExplanation)
                    }
                }
            }
        }
        .navigationTitle(Texts_BluetoothPeripheralView.signalStrength)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .colorScheme(.dark)
        .onAppear {
            now = Date()
            history = BluetoothSignalStrengthHistory(startedAt: now)
            gaugeScale = BluetoothSignalStrengthGauge()
            visible = true
            update()
        }
        .onDisappear { visible = false }
        // SwiftUI cancels polling when hidden or inactive. Protocol work stays on the Bluetooth queue.
        .task(id: visible && scenePhase == .active) {
            guard visible, scenePhase == .active else { return }
            while !Task.isCancelled {
                update()
                transmitter?.readSignalStrength()
                do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                catch { return }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bluetoothSignalStrengthDidChange)) { notification in
            guard visible, scenePhase == .active,
                  let source = notification.object as? BluetoothTransmitter,
                  source === transmitter else { return }
            update()
        }
    }

    private func update() {
        now = Date()
        let source = transmitter
        connected = source?.isSignalStrengthConnected ?? false
        sample = source?.signalStrength
        gaugeScale.observe(sample)
        if showsHistory { history.update(sample: sample, now: now) }
    }

    private var gauge: some View {
        VStack(spacing: 10) {
            HStack {
                Text(Texts_BluetoothPeripheralView.signalStrengthWeak)
                Spacer()
                Text(Texts_BluetoothPeripheralView.signalStrengthStrong)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Define transitions in dBm so stops remain ordered as the gauge expands.
                    Capsule()
                        .fill(LinearGradient(stops: [
                            .init(color: Color(.systemRed), location: 0),
                            .init(color: Color(.systemRed), location: gaugeScale.position(for: BluetoothSignalStrength.moderateFrom - 2)),
                            .init(color: Color(.systemYellow), location: gaugeScale.position(for: BluetoothSignalStrength.moderateFrom + 2)),
                            .init(color: Color(.systemYellow), location: gaugeScale.position(for: BluetoothSignalStrength.strongFrom - 2)),
                            .init(color: Color(.systemGreen), location: gaugeScale.position(for: BluetoothSignalStrength.strongFrom + 2)),
                            .init(color: Color(.systemGreen), location: 1)
                        ], startPoint: .leading, endPoint: .trailing))
                        .frame(height: Self.gaugeHeight)
                        .overlay {
                            if showsHistory, let minimum = gaugeScale.minimumRSSI, let maximum = gaugeScale.maximumRSSI {
                                // The two clipped rectangles shade outside the actual minimum and maximum.
                                // The spacer keeps the observed range clear, including after the bounds expand.
                                // Match the 3-point marker centres and clamp widths for narrow layouts.
                                let width = geometry.size.width
                                let lowerX = min(width, max(0, (width - 3) * CGFloat(gaugeScale.position(for: minimum)) + 1.5))
                                let upperX = min(width, max(lowerX, (width - 3) * CGFloat(gaugeScale.position(for: maximum)) + 1.5))
                                HStack(spacing: 0) {
                                    Rectangle().frame(width: lowerX)
                                    Spacer(minLength: 0)
                                    Rectangle().frame(width: width - upperX)
                                }
                                .foregroundStyle(Self.rangeOverlayColor.opacity(Self.rangeOverlayOpacity))
                                .clipShape(Capsule())
                                .allowsHitTesting(false)
                            }
                        }
                    // Intermittent devices show only the current marker. Deduplicate equal extremes
                    // so the first observation does not draw two translucent markers on top of each other.
                    if showsHistory {
                        ForEach(Array(Set([gaugeScale.minimumRSSI, gaugeScale.maximumRSSI].compactMap { $0 })).sorted(), id: \.self) { rssi in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray2).opacity(0.6))
                                // Limit markers fit inside the bar. Only the current marker extends above and below it.
                                .frame(width: 3, height: Self.gaugeHeight)
                                .offset(x: (geometry.size.width - 3) * CGFloat(gaugeScale.position(for: rssi)))
                        }
                    }
                    // Draw the current marker above the shading and limits. Its wider body shares
                    // their centre and stays at the last measured position when disconnected.
                    if let sample {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(!showsDisconnected && sample.isCurrent(now: now) ? Color.white : Color.gray)
                            .frame(width: 5, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .offset(x: (geometry.size.width - 3) * CGFloat(gaugeScale.position(for: sample.rssi)) - 1)
                    }
                }
                .frame(height: 28)
            }
            .frame(height: 28)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Text("\(gaugeScale.lowerBound)")
                    Text("\(BluetoothSignalStrength.moderateFrom)").position(x: geometry.size.width * CGFloat(gaugeScale.position(for: BluetoothSignalStrength.moderateFrom)), y: 8)
                    Text("\(BluetoothSignalStrength.strongFrom)").position(x: geometry.size.width * CGFloat(gaugeScale.position(for: BluetoothSignalStrength.strongFrom)), y: 8)
                    Text("\(gaugeScale.upperBound) dBm").frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Texts_BluetoothPeripheralView.signalStrength)
        .accessibilityValue(sample.map { "\($0.rssi) dBm" } ?? Texts_BluetoothPeripheralView.waiting)
    }

    private var chart: some View {
        Chart {
            RectangleMark(xStart: .value("Start", timeDomain.lowerBound), xEnd: .value("End", now),
                          yStart: .value("Minimum", signalDomain.lowerBound), yEnd: .value("Weak", BluetoothSignalStrength.moderateFrom))
                .foregroundStyle(ConstantsAppColors.urgent.opacity(0.10))
                .accessibilityHidden(true)
            RectangleMark(xStart: .value("Start", timeDomain.lowerBound), xEnd: .value("End", now),
                          yStart: .value("Weak", BluetoothSignalStrength.moderateFrom), yEnd: .value("Strong", BluetoothSignalStrength.strongFrom))
                .foregroundStyle(ConstantsAppColors.warning.opacity(0.09))
                .accessibilityHidden(true)
            RectangleMark(xStart: .value("Start", timeDomain.lowerBound), xEnd: .value("End", now),
                          yStart: .value("Strong", BluetoothSignalStrength.strongFrom), yEnd: .value("Maximum", signalDomain.upperBound))
                .foregroundStyle(ConstantsAppColors.normal.opacity(0.08))
                .accessibilityHidden(true)
            ForEach(history.points) { point in
                LineMark(x: .value(Texts_BluetoothPeripheralView.signalStrengthLastMeasurement, point.sample.measuredAt), y: .value("dBm", point.sample.rssi))
                    .foregroundStyle(Color.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                PointMark(x: .value(Texts_BluetoothPeripheralView.signalStrengthLastMeasurement, point.sample.measuredAt), y: .value("dBm", point.sample.rssi))
                    .foregroundStyle(Color.cyan)
                    .symbolSize(4)
            }
        }
        .chartXScale(domain: timeDomain)
        .chartYScale(domain: signalDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute)) { _ in
                AxisGridLine().foregroundStyle(Color(.systemGray3).opacity(0.18))
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [signalDomain.lowerBound, BluetoothSignalStrength.moderateFrom, BluetoothSignalStrength.strongFrom, signalDomain.upperBound])
        }
        .chartYAxisLabel("dBm")
        .chartLegend(.hidden)
        .accessibilityLabel(Texts_BluetoothPeripheralView.signalStrength)
    }
}

// Keep the parent indicator and child value on the same palette.
extension BluetoothSignalStrength.Band {
    var color: Color {
        switch self {
        case .strong: return Color(.systemGreen)
        case .moderate: return Color(.systemYellow)
        case .weak: return Color(.systemRed)
        }
    }
}
