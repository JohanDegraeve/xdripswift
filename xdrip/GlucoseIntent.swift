//
//  GlucoseIntent.swift
//  xdrip
//
//  Created by Guy Shaviv on 28/12/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
#endif
import Foundation
import SwiftUI

@available(iOS 16, *)
struct GlucoseIntent: AppIntent {
    static var authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    static var title: LocalizedStringResource {
        "What's my glucose level"
    }

    static var description: IntentDescription? {
        IntentDescription("Have Siri say your blood glucose level.", categoryName: "Information")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<Double> & ProvidesDialog & ShowsSnippetView {
        let coreDataManager = await CoreDataManager.create(for: ConstantsCoreData.modelName)
        let bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        let bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: Date(timeIntervalSinceNow: -14400), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).sorted { $0.timeStamp < $1.timeStamp }
        guard let mostRecent = bgReadings.last else {
            throw IntentError.message("No glucose data")
        }

        let value = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? mostRecent.calculatedValue : (mostRecent.calculatedValue * ConstantsBloodGlucose.mgDlToMmoll)
        let valueString = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? value.formatted(.number.precision(.fractionLength(0))) : value.formatted(.number.precision(.fractionLength(1)))
        let trendDescription: LocalizedStringResource = switch mostRecent.slopeTrend() {
        case .droppingFast: "dropping fast"
        case .dropping: "dropping"
        case .moderatelyDropping: "moderately dropping"
        case .stable: "stable"
        case .moderatelyRising: "moderately rising"
        case .rising: "rising"
        case .risingFast: "rising fast"
        }

        return .result(
            value: value,
            dialog: "Your blood glucose level is \(valueString) and is \(trendDescription)",
            view: GlucoseIntentResponseView(readings: bgReadings)
        )
    }
}

extension CoreDataManager {
    static func create(for modelName: String) async -> CoreDataManager {
        await withCheckedContinuation { continuation in
            let sem = DispatchSemaphore(value: 0)
            let manager = CoreDataManager(modelName: modelName) {
                sem.signal()
            }
            sem.wait()
            continuation.resume(returning: manager)
        }
    }
}

@available(iOS 16, *)
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let message):
            LocalizedStringResource(stringLiteral: message)
        }
    }
}

private enum Trend {
    case droppingFast
    case dropping
    case moderatelyDropping
    case stable
    case moderatelyRising
    case rising
    case risingFast
}

private extension BgReading {
    func slopeTrend() -> Trend {
        switch calculatedValueSlope * 60000 {
        case ..<(-2): .droppingFast
        case -2 ..< -1: .dropping
        case -1 ..< -0.5: .moderatelyDropping
        case -0.5 ..< 0.5: .stable
        case 0.5 ..< 1: .moderatelyRising
        case 1 ..< 2: .rising
        default: .risingFast
        }
    }
}
