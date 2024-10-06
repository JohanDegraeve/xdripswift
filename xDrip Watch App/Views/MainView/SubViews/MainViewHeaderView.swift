//
//  MainViewHeaderView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 21/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

struct MainViewHeaderView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    let isSmallScreen = WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen ? true : false
    
    let originalTextScaleValue = 1.0
    let animatedTextScaleValue = 1.1
    @State private var textScaleValue = 1.0
    
    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("\(watchState.bgValueStringInUserChosenUnit())\(watchState.trendArrow())")
                .font(.system(size: isSmallScreen ? 40 : 50)).fontWeight(.semibold)
                .foregroundStyle(watchState.bgTextColor())
                .scaledToFill()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 0) {
                Spacer()
                
                Text(watchState.deltaChangeStringInUserChosenUnit())
                    .font(.system(size: isSmallScreen ? 24 : 28)).fontWeight(.semibold)
                    .lineLimit(1)
                    .padding(.bottom, isSmallScreen ? -5 : -6)
                
                Text(watchState.bgUnitString())
                    .font(.system(size: isSmallScreen ? 12 : 14))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .scaleEffect(textScaleValue)
        .padding(.trailing, 10)
        .animation(.easeOut(duration: 0.3), value: textScaleValue)
        .onChange(of: watchState.bgValueStringInUserChosenUnit()) { oldState, newState in
            animateTextScale()
        }
        .onChange(of: watchState.updateMainViewDate) { oldState, newState in
            animateTextScale()
        }
    }
    
    func animateTextScale(){
        textScaleValue = animatedTextScaleValue
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3){
            textScaleValue = originalTextScaleValue
        }
    }
}

struct MainViewHeaderView_Previews: PreviewProvider {
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
            } else if currentValue > 180 {
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
        let watchState = WatchStateModel()
        
        watchState.bgReadingValues = bgValueArray()
        watchState.bgReadingDates = bgDateArray()
        watchState.isMgDl = true
        watchState.slopeOrdinal = 5
        watchState.deltaValueInUserUnit = -2
        watchState.urgentLowLimitInMgDl = 60
        watchState.lowLimitInMgDl = 80
        watchState.highLimitInMgDl = 140
        watchState.urgentHighLimitInMgDl = 180
        watchState.updatedDate = Date().addingTimeInterval(-120)
        watchState.activeSensorDescription = "Data Source"
        watchState.sensorAgeInMinutes = Double(Int.random(in: 1..<14400))
        watchState.sensorMaxAgeInMinutes = 14400
        
        return Group {
            MainViewHeaderView()
        }.environmentObject(watchState)
    }
}
