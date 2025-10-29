//
//  XDripWidget+Provider.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WidgetKit
import Foundation

extension XDripWidget {
    struct Provider: TimelineProvider {
        
        func placeholder(in context: Context) -> Entry {
            .placeholder
        }
        
        func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
            completion(.placeholder)
        }
        
        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
            let entry = Entry(date: .now, widgetState: getWidgetStateFromSharedUserDefaults() ?? sampleWidgetStateFromProvider)
                
            completion(.init(entries: [entry], policy: .atEnd))
        }
    }
}


// MARK: - Helpers

extension XDripWidget.Provider {
    func getWidgetStateFromSharedUserDefaults() -> XDripWidget.Entry.WidgetState? {
        
        guard let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName) else {return nil}
        
        guard let encodedLatestReadings = sharedUserDefaults.data(forKey: "widgetSharedUserDefaults.\(Bundle.main.mainAppBundleIdentifier)") else {
            return nil
        }
        
        let decoder = JSONDecoder()

        do {
            let data = try decoder.decode(WidgetSharedUserDefaultsModel.self, from: encodedLatestReadings)
            
            // because dates aren't Codable we stored them as doubles
            // we need to convert the bgReadingDatesAsDouble key values to an array of real dates
            let bgReadingDates: [Date] = data.bgReadingDatesAsDouble.map { date in
                Date(timeIntervalSince1970: date)
            }
            
            return Entry.WidgetState(bgReadingValues: data.bgReadingValues, bgReadingDates: bgReadingDates, isMgDl: data.isMgDl, slopeOrdinal: data.slopeOrdinal, deltaValueInUserUnit: data.deltaValueInUserUnit, urgentLowLimitInMgDl: data.urgentLowLimitInMgDl, lowLimitInMgDl: data.lowLimitInMgDl, highLimitInMgDl: data.highLimitInMgDl, urgentHighLimitInMgDl: data.urgentHighLimitInMgDl, dataSourceDescription: data.dataSourceDescription, followerPatientName: data.followerPatientName, deviceStatusCreatedAt: data.deviceStatusCreatedAt, deviceStatusLastLoopDate: data.deviceStatusLastLoopDate, allowStandByHighContrast: data.allowStandByHighContrast, forceStandByBigNumbers: data.forceStandByBigNumbers)
        } catch {
            print(error.localizedDescription)
        }
              
        return sampleWidgetStateFromProvider
    }
    
    private var sampleWidgetStateFromProvider: XDripWidget.Entry.WidgetState {        
        func bgDateArray() -> [Date] {
            let endDate = Date()
            let startDate = endDate.addingTimeInterval(-3600 * 12)
            var currentDate = startDate
            
            var dateArray: [Date] = []
            
            while currentDate < endDate {
                dateArray.append(currentDate)
                currentDate = currentDate.addingTimeInterval(60 * 5)
            }
            return dateArray
        }
        
        func bgValueArray() -> [Double] {
            
            var bgValueArray:[Double] = Array(repeating: 0, count: 144)
            var currentValue: Double = 100
            var increaseValues: Bool = true
            
            for index in bgValueArray.indices {
                let randomValue = Double(Int.random(in: -10..<10))
                
                if currentValue < 75 {
                    increaseValues = true
                    bgValueArray[index] = currentValue + abs(randomValue)
                } else if currentValue > 150 {
                    increaseValues = false
                    bgValueArray[index] = currentValue - abs(randomValue)
                } else {
                    bgValueArray[index] = currentValue + (increaseValues ? randomValue : -randomValue)
                }
                currentValue = bgValueArray[index]
            }
            return bgValueArray
        }
        
        return Entry.WidgetState(bgReadingValues: bgValueArray(), bgReadingDates: bgDateArray(), isMgDl: true, slopeOrdinal: 1, deltaValueInUserUnit: 0, urgentLowLimitInMgDl: ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl, lowLimitInMgDl: ConstantsBGGraphBuilder.defaultLowMarkInMgdl, highLimitInMgDl: ConstantsBGGraphBuilder.defaultHighMarkInMgdl, urgentHighLimitInMgDl: ConstantsBGGraphBuilder.defaultUrgentHighMarkInMgdl, dataSourceDescription: "Dexcom G6", followerPatientName: nil, deviceStatusCreatedAt: Date().addingTimeInterval(-200), deviceStatusLastLoopDate: Date().addingTimeInterval(-120))
    }
}

