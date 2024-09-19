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

struct GlucoseIntent: AppIntent {
    static var authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    static var title: LocalizedStringResource {
        "What's my glucose level"
    }

    static var description: IntentDescription? {
        IntentDescription("Ask to read out your blood glucose level.", categoryName: "Information")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<Double> & ProvidesDialog & ShowsSnippetView {
        let coreDataManager = await CoreDataManager.create(for: ConstantsCoreData.modelName)
        
        let bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        let bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: Date(timeIntervalSinceNow: -14400), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).sorted { $0.timeStamp < $1.timeStamp }
        
        guard let mostRecent = bgReadings.last else {
            throw IntentError.message("No glucose data")
        }
        
        let value = mostRecent.calculatedValue.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) // UserDefaults.standard.bloodGlucoseUnitIsMgDl ? mostRecent.calculatedValue : (mostRecent.calculatedValue * ConstantsBloodGlucose.mgDlToMmoll)
        
        let valueString = value.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) // UserDefaults.standard.bloodGlucoseUnitIsMgDl ? value.formatted(.number.precision(.fractionLength(0))) : value.formatted(.number.precision(.fractionLength(1)))
        
        let trendDescription: LocalizedStringResource = switch mostRecent.slopeTrend() {
        case .droppingFast: "dropping fast"
        case .dropping: "dropping"
        case .slowlyDropping: "slowly dropping"
        case .stable: "stable"
        case .slowlyRising: "slowly rising"
        case .rising: "rising"
        case .risingFast: "rising fast"
        }
        
        var bgReadingValues: [Double] = []
        var bgReadingDates: [Date] = []
        
        for bgReading in bgReadings {
            bgReadingValues.append(bgReading.calculatedValue)
            bgReadingDates.append(bgReading.timeStamp)
        }
        
        var dialogString: IntentDialog = "Your blood glucose is currently \(valueString) and \(trendDescription)"
        
        let minutesAgo = (bgReadingDates.last?.timeIntervalSinceNow ?? 999 ) / 60
        
        let minutesAgoString = abs(Int(minutesAgo))
        
        if minutesAgo < -30 {
            dialogString = "Sorry, there are no recent blood glucose values."
        } else if minutesAgo < -7 {
            dialogString = "\(minutesAgoString) minutes ago your blood glucose was \(valueString) "
        }
        
        return .result(
            value: value,
            dialog: dialogString,
            view: GlucoseChartView(glucoseChartType: .siriGlucoseIntent, bgReadingValues: bgReadingValues, bgReadingDates: bgReadingDates, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue, lowLimitInMgDl: UserDefaults.standard.lowMarkValue, highLimitInMgDl: UserDefaults.standard.highMarkValue, urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue, liveActivitySize: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
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
    case slowlyDropping
    case stable
    case slowlyRising
    case rising
    case risingFast
}

private extension BgReading {
    func slopeTrend() -> Trend {
        switch calculatedValueSlope * 60000 {
        case ..<(-2):
                .droppingFast
        case -2 ..< -1: 
                .dropping
        case -1 ..< -0.5: 
                .slowlyDropping
        case -0.5 ..< 0.5:
                .stable
        case 0.5 ..< 1: 
                .slowlyRising
        case 1 ..< 2:
                .rising
        default: 
                .risingFast
        }
    }
}
