//
//  DirectWatchCollectionView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 12/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WatchKit

struct DirectWatchCollectionView: View {
    @EnvironmentObject private var watchState: WatchStateModel
    @ObservedObject var collector: DirectWatchCollector
    // The app-level NavigationStack owns presentation. This carousel page must not register
    // destinations: lazy page recreation would pop the child or hide its destination.
    let onCollectedReadings: () -> Void
    let onAlerts: () -> Void
    @State private var showsResetConfirmation = false
    @State private var logFeedback: Bool?
    @State private var resetFeedback: Bool?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(TextsDirectWatch.title).font(.headline)
                        Spacer(minLength: 4)
                    }

                    if let configuration = collector.configuration {
                        let latest = collector.latestReadingAt
                        let collectionStatus = DirectWatchReadingStatus(isConfigured: true, isSuspended: false,
                                                                        latestReadingAt: latest, now: timeline.date,
                                                                        isPaused: collector.isPaused,
                                                                        resumedAt: collector.collectionResumedAt,
                                                                        lastConnectedAt: collector.lastConnectedAt)
                        let isCollecting = collectionStatus == .current || collectionStatus == .delayed
                        let isStarting = collectionStatus == .connecting || collectionStatus == .waiting

                        DirectWatchStatusBanner(isConfigured: true, isSuspended: false, isPaused: collector.isPaused,
                                                latestReadingAt: latest, lastConnectedAt: collector.lastConnectedAt,
                                                resumedAt: collector.collectionResumedAt,
                                                pausedAt: collector.isPaused ? collector.collectionControl?.changedAt : nil, now: timeline.date)
                            .padding(.top, 10)
                        DirectWatchCollectionControlButton(isPaused: collector.isPaused) {
                            collector.setPaused(!collector.isPaused)
                        }
                        .padding(.top, 8)

                        if !collector.isPaused && !isCollecting && !isStarting {
                            Text(collector.status)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .padding(.top, 7)
                        }

                        Divider().padding(.vertical, 9)
                        sectionHeader(TextsDirectWatch.connectionDetails)
                        statusRow("antenna.radiowaves.left.and.right", TextsDirectWatch.cgm,
                                  collectionStatus.title,
                                  color: ConstantsDirectWatch.statusColor(for: collectionStatus))
                        let phone = phoneStatus(at: timeline.date)
                        statusRow("iphone", "iPhone", phone.text, color: phone.color)
                        statusRow("arrow.up.circle", TextsDirectWatch.toSync, String(format: collector.pendingCount == 1 ? TextsDirectWatch.oneReadingFormat : TextsDirectWatch.readingsFormat, collector.pendingCount))

                        Divider().padding(.vertical, 9)
                        connectionDetailRow(TextsDirectWatch.cgmType, deviceName(configuration))
                        connectionDetailRow(TextsDirectWatch.bluetoothSlot, "\(configuration.slot)")
                    } else {
                        DirectWatchStatusBanner(isConfigured: collector.isConfigured,
                                                isSuspended: collector.isConfigured, isPaused: collector.isPaused,
                                                latestReadingAt: nil, lastConnectedAt: collector.lastConnectedAt,
                                                resumedAt: collector.collectionResumedAt,
                                                pausedAt: collector.isPaused ? collector.collectionControl?.changedAt : nil, now: timeline.date)
                            .padding(.top, 10)
                        if collector.isConfigured {
                            DirectWatchCollectionControlButton(isPaused: collector.isPaused) {
                                collector.setPaused(!collector.isPaused)
                            }
                            .padding(.top, 8)
                        }
                        Text(collector.isConfigured
                             ? TextsDirectWatch.checkSensor
                             : TextsDirectWatch.addOnPhone)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                    Divider().padding(.vertical, 9)
                    Button(action: onAlerts) {
                        actionLabel(TextsDirectWatch.alerts)
                    }
                    .buttonStyle(DirectWatchButtonStyle())
                    Divider().padding(.vertical, 9)
                    sectionHeader(TextsDirectWatch.diagnosis)
                    Button(action: onCollectedReadings) {
                        actionLabel(TextsDirectWatch.collectedReadings)
                    }
                    .buttonStyle(DirectWatchButtonStyle())
                    .padding(.bottom, 6)
                    if collector.configuration != nil {
                        Button { showsResetConfirmation = true } label: {
                            actionLabel(TextsDirectWatch.resetConnection, feedback: resetFeedback, confirmation: TextsDirectWatch.resetStarted)
                        }
                        .buttonStyle(DirectWatchButtonStyle())
                        .disabled(collector.isPaused || resetFeedback != nil)
                        .padding(.bottom, 6)
                    }
                    Button {
                        let queued = collector.sendLogs()
                        logFeedback = queued
                        WKInterfaceDevice.current().play(queued ? .success : .failure)
                    } label: {
                        actionLabel(TextsDirectWatch.sendLogs, feedback: logFeedback, confirmation: TextsDirectWatch.logsQueued)
                    }
                    .buttonStyle(DirectWatchButtonStyle())
                    .disabled(logFeedback != nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 10)
            }
        }
        .alert(TextsDirectWatch.resetConnection, isPresented: $showsResetConfirmation) {
            Button(TextsDirectWatch.resetConnection, role: .destructive) {
                let started = collector.resetBluetoothConnection()
                resetFeedback = started
                WKInterfaceDevice.current().play(started ? .success : .failure)
            }
            Button(TextsDirectWatch.cancel, role: .cancel) { }
        } message: {
            Text(TextsDirectWatch.resetConnectionExplanation)
        }
        // Keep feedback outside the updating carousel content, and cancel it on navigation.
        .task(id: logFeedback) {
            guard logFeedback != nil else { return }
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                logFeedback = nil
            } catch { }
        }
        .task(id: resetFeedback) {
            guard resetFeedback != nil else { return }
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                resetFeedback = nil
            } catch { }
        }
    }

    private func actionLabel(_ title: String, feedback: Bool? = nil, confirmation: String = "") -> some View {
        HStack(spacing: 5) {
            if let feedback {
                Image(systemName: feedback ? "checkmark" : "exclamationmark.circle")
                    .foregroundStyle(feedback ? Color.green : .red)
            }
            Text(feedback.map { $0 ? confirmation : TextsDirectWatch.tryAgain } ?? title)
        }
        .font(.system(size: 17))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16))
            .foregroundStyle(.colorPrimary)
            .padding(.bottom, 7)
    }

    private func connectionDetailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color("colorPrimary"))
            Spacer(minLength: 4)
            Text(value)
        }
        .font(.system(size: 16))
        .foregroundStyle(Color("colorSecondary"))
        .fontWeight(.regular)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(minHeight: 34)
    }

    // Phone communication is separate from Watch collection state.
    private func phoneStatus(at date: Date) -> (text: String, color: Color) {
        if watchState.phoneLinkIsLive(at: date) {
            return watchState.phoneBLECollectionPaused ? (TextsDirectWatch.blePaused, .orange) : (TextsDirectWatch.connected, .green)
        }
        return watchState.phoneLinkIsChecking(at: date) ? (TextsDirectWatch.checking, .orange) : (TextsDirectWatch.away, .red)
    }

    private func statusRow(_ symbol: String, _ title: String, _ value: String, color: Color = Color("colorSecondary")) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).frame(width: 16)
                .foregroundStyle(Color("colorPrimary"))
            Text(title).foregroundStyle(Color("colorPrimary"))
            Spacer(minLength: 3)
            Text(value).foregroundStyle(color)
        }
        .font(.system(size: 16))
        .fontWeight(.regular)
        .foregroundStyle(Color("colorSecondary"))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(minHeight: 34)
    }

    private func deviceName(_ configuration: DirectWatchConfiguration) -> String {
        configuration.deviceName ?? (configuration.transmitterFamily == .g7 ? TextsDirectWatch.g7Family : configuration.isAnubis ? "Anubis G6" : "G6")
    }

}
