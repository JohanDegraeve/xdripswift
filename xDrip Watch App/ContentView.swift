//
//  ContentView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: WatchStateModel
    
    var body: some View {
        VStack {
            HStack {
                Text("\(state.bgReadingValues[0].mgdlToMmolAndToString(mgdl: state.isMgDl))\(state.trendArrow())")
                    .font(.system(size: 60)).bold()
                    .foregroundStyle(state.getBgColor())
                    .scaledToFill()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(state.getDeltaChangeStringInUserChosenUnit())
                        .font(.system(size: 20)).bold()
                        .lineLimit(1)
                    Text(state.bgUnitString())
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding([.leading, .trailing], 5) // needed to fit 49mm screens (Ultra 1/2)
            .padding([.top], 20)
            .padding([.bottom], -10)
            
//            .padding([.bottom], -20) // needed if the below view is shown
            
//            HStack {
//                HStack(spacing: 0) {
//                    Text("IOB: ")
//                        .font(.system(size: 12)).bold()
            
//                    Text("4.5U")
//                        .font(.system(size: 12))
//                        .foregroundStyle(.secondary)
//                }
//                Spacer()
//                
//                HStack(spacing: 0) {
//                    Text("COB: ")
//                        .font(.system(size: 12)).bold()
            
//                    Text("28g")
//                        .font(.system(size: 12))
//                        .foregroundStyle(.secondary)
//                }
//                
//                Spacer()
//                Text(state.updatedDate.formatted(date: .omitted, time: .shortened))
//                    .font(.system(size: 12))
//            }
//            .padding(.top, 10)
            
            GlucoseChartWatchView(bgReadingValues: state.bgReadingValues, bgReadingDates: state.bgReadingDates, isMgDl: state.isMgDl, urgentLowLimitInMgDl: state.urgentLowLimitInMgDl, lowLimitInMgDl: state.lowLimitInMgDl, highLimitInMgDl: state.highLimitInMgDl, urgentHighLimitInMgDl: state.urgentHighLimitInMgDl)
                .padding(.bottom, 5)
            
            Spacer()
            
            VStack(spacing: 0) {
                HStack {
                    Text(state.activeSensorDescription)
                        .font(.system(size: 12)).bold()
                    
                    Spacer()
                    
                    Text(state.sensorAgeInMinutes.minutesToDaysAndHours())
                        .font(.system(size: 12))
                        .foregroundStyle(state.activeSensorProgress().textColor)
                    
                }
                .padding([.leading, .trailing], 10)
                
                ProgressView(value: Float(state.activeSensorProgress().progress))
                    .tint(state.activeSensorProgress().progressColor)
                    .scaleEffect(x: 0.7, y: 0.3, anchor: .center)
            }
        }
        .padding(.bottom, 20)
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static func bgDateArray() -> [Date] {
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
    
    static func bgValueArray() -> [Double] {
        
        var bgValueArray:[Double] = Array(repeating: 0, count: 144)
        var currentValue: Double = 120
        var increaseValues: Bool = true
        
        for index in bgValueArray.indices {
            let randomValue = Double(Int.random(in: -10..<30))
            
            if currentValue < 70 {
                increaseValues = true
                bgValueArray[index] = currentValue + abs(randomValue)
            } else if currentValue > 200 {
                increaseValues = false
                bgValueArray[index] = currentValue - abs(randomValue)
            } else {
                bgValueArray[index] = currentValue + (increaseValues ? randomValue : -randomValue)
            }
            currentValue = bgValueArray[index]
        }
        
        return bgValueArray
        
    }
    
    static var previews: some View {
        let state = WatchStateModel()
        
        state.bgReadingValues = bgValueArray()
        state.bgReadingDates = bgDateArray()
        state.isMgDl = true
        state.slopeOrdinal = 5
        state.deltaChangeInMgDl = -2
        state.urgentLowLimitInMgDl = 60
        state.lowLimitInMgDl = 80
        state.highLimitInMgDl = 140
        state.urgentHighLimitInMgDl = 180
        state.updatedDate = Date().addingTimeInterval(-400)
        state.activeSensorDescription = "Dexcom G6"
        state.sensorAgeInMinutes = 6788
        state.sensorMaxAgeInMinutes = 14400
        
        return Group {
            ContentView()
        }.environmentObject(state)
    }
}
