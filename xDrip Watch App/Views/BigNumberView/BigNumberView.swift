//
//  BigNumberView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 21/7/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct BigNumberView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    let isSmallScreen = WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen ? true : false
    
    let originalTextScaleValue = 1.0
    let animatedTextScaleValue = 1.4
    @State private var textScaleValue = 1.0
    
    let originalGaugeOpacityValue = 0.8
    let animatedGaugeOpacityValue = 1.0
    @State private var gaugeOpacityValue = 0.8
    
    let originalMinsAgoTextColor = Color.colorSecondary
    let animatedMinsAgoTextColor = Color.white
    @State private var minsAgoTextColor = Color.colorSecondary
    
    var body: some View {
        VStack(alignment: .center ,spacing: 0) {
            Text("\(watchState.bgValueStringInUserChosenUnit())")
                .scaleEffect(textScaleValue)
                .font(.system(size:  isSmallScreen ? 100 : 120)).fontWeight(.semibold)
                .foregroundStyle(watchState.bgTextColor())
                .padding(.top, isSmallScreen ? -15 : -20)
                .padding(.trailing, 10)
                .minimumScaleFactor(0.5)
                .animation(.easeOut(duration: 0.3), value: textScaleValue)
                .onChange(of: watchState.bgValueStringInUserChosenUnit()) { oldState, newState in
                    animateTextScale()
                }
                .onChange(of: watchState.updateBigNumberViewDate) { oldState, newState in
                    animateTextScale()
                }
                .onTapGesture(count: 2) {
                    watchState.updateBigNumberViewDate = Date()
                    watchState.requestWatchStateUpdate()
                }
            
            HStack(alignment: .center, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(watchState.deltaChangeStringInUserChosenUnit())
                        .font(.system(size: isSmallScreen ? 22 : 24)).fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(watchState.bgUnitString())
                        .font(.system(size: isSmallScreen ? 22 : 24))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
                
                Text("\(watchState.trendArrow())")
                    .font(.system(size: isSmallScreen ? 34 : 38)).fontWeight(.bold)
                    .foregroundStyle(.colorPrimary)
                    .minimumScaleFactor(0.5)
            }
            .padding(.top, -20)
            .padding(.bottom, 10)
            
            VStack(alignment: .center, spacing: 1) {
                Gauge(value: watchState.bgValueInMgDl() ?? watchState.gaugeModel().nilValue, in: watchState.gaugeModel().minValue...watchState.gaugeModel().maxValue) {
                    // empty. No need for any labels or descriptions
                }
                .tint(watchState.gaugeModel().gaugeGradient)
                .gaugeStyle(.accessoryLinear)
                .opacity(gaugeOpacityValue)
                .scaleEffect(0.8)
                .animation(.easeOut(duration: 0.3), value: gaugeOpacityValue)
                .onChange(of: watchState.bgValueStringInUserChosenUnit()) { oldState, newState in
                    animateGaugeOpacityValue()
                }
                .onChange(of: watchState.updateBigNumberViewDate) { oldState, newState in
                    animateGaugeOpacityValue()
                }
            }
            
            HStack(alignment: .center, spacing: 3) {
                Image(systemName: ConstantsAppleWatch.requestingDataIconSFSymbolName)
                    .font(.system(size: ConstantsAppleWatch.requestingDataIconFontSize, weight: .heavy))
                    .foregroundStyle(watchState.requestingDataIconColor)
                    .padding(.top, 4)
                    .padding(.trailing, 2)
                
                Text(watchState.lastUpdatedMinsAgoString())
                    .font(.system(size: isSmallScreen ? 20 : 22))
                    .foregroundStyle(minsAgoTextColor)
                    .animation(.easeOut(duration: 0.3), value: minsAgoTextColor)
                    .onChange(of: watchState.lastUpdatedMinsAgoString()) { oldState, newState in
                        animateTextColor()
                    }
            }
            .padding(.top, 15)
            .padding(.bottom, -20)
        }
    }
    
    func animateTextScale(){
        textScaleValue = animatedTextScaleValue
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3){
            textScaleValue = originalTextScaleValue
        }
    }
    
    func animateTextColor(){
        minsAgoTextColor = animatedMinsAgoTextColor
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3){
            minsAgoTextColor = watchState.lastUpdatedTimeColor()
        }
    }
    
    func animateGaugeOpacityValue(){
        gaugeOpacityValue = animatedGaugeOpacityValue
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3){
            gaugeOpacityValue = originalGaugeOpacityValue
        }
    }
}

struct BigNumberView_Previews: PreviewProvider {
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
        watchState.highLimitInMgDl = 180
        watchState.urgentHighLimitInMgDl = 240
        watchState.updatedDate = Date().addingTimeInterval(-120)
        watchState.activeSensorDescription = "Data Source"
        watchState.sensorAgeInMinutes = Double(Int.random(in: 1..<14400))
        watchState.sensorMaxAgeInMinutes = 14400
        
        return Group {
            BigNumberView()
        }.environmentObject(watchState)
    }
}
