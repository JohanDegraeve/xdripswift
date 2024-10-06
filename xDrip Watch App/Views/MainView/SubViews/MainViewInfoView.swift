//
//  MainViewInfoView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 24/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

struct MainViewInfoView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    let isSmallScreen = WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen ? true : false
    
    let originalMinsAgoTextColor = Color.colorSecondary
    let animatedMinsAgoTextColor = Color.white
    @State private var minsAgoTextColor = Color.colorSecondary
    
    var body: some View {
        
        let textSize: CGFloat = isSmallScreen ? 14 : 16
        
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: ConstantsAppleWatch.requestingDataIconSFSymbolName)
                .font(.system(size: ConstantsAppleWatch.requestingDataIconFontSize, weight: .heavy))
                .foregroundStyle(watchState.requestingDataIconColor)
                .padding(.top, 4)
                .padding(.trailing, 2)
            
            Text(watchState.lastUpdatedMinsAgoString())
                .font(.system(size: textSize))
                .foregroundStyle(minsAgoTextColor)
                .animation(.easeOut(duration: 0.3), value: minsAgoTextColor)
                .onChange(of: watchState.lastUpdatedMinsAgoString()) { oldState, newState in
                    animateTextColor()
                }
        }
    }
    
    func animateTextColor(){
        minsAgoTextColor = animatedMinsAgoTextColor
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3){
            minsAgoTextColor = watchState.lastUpdatedTimeColor()
        }
    }
}

struct MainViewInfoView_Previews: PreviewProvider {
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
            MainViewInfoView()
        }.environmentObject(watchState)
    }
}
