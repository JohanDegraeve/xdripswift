//
//  Libre3SensorLifecycle.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/SensorLifecycle.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

enum Libre3SensorLifecyclePhase: String, Equatable, Sendable {
    case warmup
    case active
    case expired
}

struct Libre3SensorLifecycle: Equatable, Sendable {
    static let defaultWarmupDurationMinutes = 60

    let currentLifeCountMinutes: Int
    let warmupDurationMinutes: Int
    let wearDurationMinutes: Int?

    init(
        currentLifeCountMinutes: Int,
        warmupDurationMinutes: Int = Self.defaultWarmupDurationMinutes,
        wearDurationMinutes: Int? = nil
    ) {
        self.currentLifeCountMinutes = currentLifeCountMinutes
        self.warmupDurationMinutes = max(0, warmupDurationMinutes)
        self.wearDurationMinutes = wearDurationMinutes.map { max(0, $0) }
    }

    var elapsedMinutes: Int {
        max(0, currentLifeCountMinutes)
    }

    var remainingWarmupMinutes: Int {
        max(0, warmupDurationMinutes - elapsedMinutes)
    }

    var remainingWearMinutes: Int? {
        wearDurationMinutes.map { max(0, $0 - elapsedMinutes) }
    }

    var isWarmupComplete: Bool {
        elapsedMinutes >= warmupDurationMinutes
    }

    var isWarmingUp: Bool {
        !isWarmupComplete && !isExpired
    }

    var isExpired: Bool {
        guard let wearDurationMinutes else {
            return false
        }
        return elapsedMinutes >= wearDurationMinutes
    }

    var isActive: Bool {
        phase == .active
    }

    var phase: Libre3SensorLifecyclePhase {
        if isExpired {
            return .expired
        }
        if !isWarmupComplete {
            return .warmup
        }
        return .active
    }
}
