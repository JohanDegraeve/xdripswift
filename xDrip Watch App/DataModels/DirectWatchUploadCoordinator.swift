//
//  DirectWatchUploadCoordinator.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 26/11/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import Foundation

#if os(iOS)
@testable import xdrip
#endif

/// Routes each Watch reading to the configured services and keeps their upload status separate.
@MainActor final class DirectWatchUploadCoordinator: ObservableObject {
    let nightscoutUploader: DirectWatchNightscoutUploader
    let dexcomShareUploader: DirectWatchDexcomShareUploader
    @Published private(set) var cloudUploadEnabled = false

    init(nightscoutUploader: DirectWatchNightscoutUploader? = nil,
         dexcomShareUploader: DirectWatchDexcomShareUploader? = nil) {
        let nightscoutUploader = nightscoutUploader ?? DirectWatchNightscoutUploader()
        let dexcomShareUploader = dexcomShareUploader ?? DirectWatchDexcomShareUploader()
        self.nightscoutUploader = nightscoutUploader
        self.dexcomShareUploader = dexcomShareUploader
        // Restore the switch so the Watch can resume uploads after a restart while the iPhone is away.
        cloudUploadEnabled = UserDefaults.standard.object(forKey: DirectWatchUploadSettings.enabledKey) as? Bool
            ?? (nightscoutUploader.isConfiguredToUpload || dexcomShareUploader.isConfiguredToUpload)
        nightscoutUploader.onStatusChange = { [weak self] in self?.objectWillChange.send() }
        dexcomShareUploader.onStatusChange = { [weak self] in self?.objectWillChange.send() }
    }

    var isUploading: Bool { nightscoutUploader.isUploading || dexcomShareUploader.isUploading }
    var statusPayload: [String: Any] {
        [DirectWatchUploadSettings.statusKey: nightscoutUploader.statusPayload
            .merging(dexcomShareUploader.statusPayload, uniquingKeysWith: { _, new in new })]
    }

    func isReady(_ service: DirectWatchUploadService) -> Bool {
        switch service {
        case .nightscout: return nightscoutUploader.isReady
        case .dexcomShare: return dexcomShareUploader.isReady
        }
    }

    func readingStatus(for reading: DirectWatchReading, service: DirectWatchUploadService) -> DirectWatchServiceReadingStatus {
        switch service {
        case .nightscout: return nightscoutUploader.readingStatus(for: reading)
        case .dexcomShare: return dexcomShareUploader.readingStatus(for: reading)
        }
    }

    func receiveConfiguration(_ payload: [String: Any]) {
        if let enabled = payload[DirectWatchUploadSettings.enabledKey] as? Bool {
            cloudUploadEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: DirectWatchUploadSettings.enabledKey)
        }
        nightscoutUploader.receiveConfiguration(payload)
        dexcomShareUploader.receiveConfiguration(payload)
    }

    // With normal sync, the phone uploads while it is reachable. Disabling sync lets us test Watch uploads nearby.
    func shouldOwnNewReading(collectedAt: Date, phoneReachable: Bool, phoneSyncDisabled: Bool) -> DirectWatchUploadOwnership {
        guard cloudUploadEnabled else { return DirectWatchUploadOwnership() }
        return DirectWatchUploadOwnership(
            nightscout: nightscoutUploader.shouldOwnNewReading(collectedAt: collectedAt,
                phoneReachable: phoneReachable, phoneSyncDisabled: phoneSyncDisabled),
            dexcomShare: dexcomShareUploader.shouldOwnNewReading(collectedAt: collectedAt,
                phoneReachable: phoneReachable, phoneSyncDisabled: phoneSyncDisabled))
    }

    /// Mark ownership for each service only if its queue saved the reading.
    func stageReading(_ reading: DirectWatchReading, alongside readings: [DirectWatchReading],
               phoneReachable: Bool, phoneSyncDisabled: Bool) -> DirectWatchUploadOwnership {
        let candidate = shouldOwnNewReading(collectedAt: reading.collectedAt ?? .distantPast,
                                            phoneReachable: phoneReachable, phoneSyncDisabled: phoneSyncDisabled)
        let nightscout = candidate.nightscout && nightscoutUploader.stageReading(reading, alongside: readings)
        let dexcomShare = candidate.dexcomShare && dexcomShareUploader.stageReading(reading, alongside: readings)
        return DirectWatchUploadOwnership(nightscout: nightscout, dexcomShare: dexcomShare)
    }

    // Only the matching ownership flag can confirm a staged upload after a restart.
    func reconcileStagedReadings(in readings: [DirectWatchReading]) {
        nightscoutUploader.reconcileStagedReadings(committedIDs: Set(readings.lazy.filter { $0.watchNightscoutOwned == true }.map(\.id)))
        dexcomShareUploader.reconcileStagedReadings(committedIDs: Set(readings.lazy.filter { $0.watchDexcomShareOwned == true }.map(\.id)))
    }

    func retryPendingUploads() {
        nightscoutUploader.retryPendingUploads()
        dexcomShareUploader.retryPendingUploads()
    }
}
