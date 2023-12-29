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
        if UserDefaults.standard.bloodGlucoseUnitIsMgDl {
            return .result(
                value: mostRecent.calculatedValue,
                dialog: "Your blood glucose level is \(mostRecent.calculatedValue.formatted(.number.precision(.fractionLength(0))))",
                view: GlucoseIntentResponseView(readings: bgReadings)
            )
        } else {
            let value = mostRecent.calculatedValue * ConstantsBloodGlucose.mgDlToMmoll
            return .result(
                value: value,
                dialog: "Your blood glucose level is \(value.formatted(.number.precision(.fractionLength(1))))",
                view: GlucoseIntentResponseView(readings: bgReadings)
            )
        }
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
