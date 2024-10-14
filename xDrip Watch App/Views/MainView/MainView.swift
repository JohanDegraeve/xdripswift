//
//  MainView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    // get the array of different hour ranges from the constants file
    // we'll move through this array as the user swipes left/right on the chart
    let hoursToShow: [Double] = ConstantsAppleWatch.hoursToShow
    
    @State private var hoursToShowIndex: Int = ConstantsAppleWatch.hoursToShowDefaultIndex
    
    @State private var showDebug: Bool = false
    
    let isSmallScreen = WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen ? true : false
    
    // MARK: -  Body
    var body: some View {
        
        let overrideChartHeight: Double? = isSmallScreen ? ConstantsGlucoseChartSwiftUI.viewHeightWatchAppSmall : nil
        
        let overrideChartWidth: Double? = isSmallScreen ? ConstantsGlucoseChartSwiftUI.viewWidthWatchAppSmall : nil
        
        ZStack(alignment: Alignment(horizontal: .center, vertical: .center), content: {
            VStack(spacing: 2) {
                MainViewHeaderView()
                    .padding([.leading, .trailing], 5)
                    .padding([.top], -6)
                    .padding([.bottom], -6)
                    .onTapGesture(count: 2) {
                        watchState.updateMainViewDate = Date()
                        watchState.requestWatchStateUpdate()
                    }
                
                GlucoseChartView(glucoseChartType: .watchApp, bgReadingValues: watchState.bgReadingValues, bgReadingDates: watchState.bgReadingDates, isMgDl: watchState.isMgDl, urgentLowLimitInMgDl: watchState.urgentLowLimitInMgDl, lowLimitInMgDl: watchState.lowLimitInMgDl, highLimitInMgDl: watchState.highLimitInMgDl, urgentHighLimitInMgDl: watchState.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: hoursToShow[hoursToShowIndex], glucoseCircleDiameterScalingHours: 4, overrideChartHeight: overrideChartHeight, overrideChartWidth: overrideChartWidth, highContrast: nil)
                    .gesture(
                        DragGesture(minimumDistance: 80, coordinateSpace: .local)
                            .onEnded({ value in
                                if (value.startLocation.x > value.location.x) {
                                    if hoursToShow[hoursToShowIndex] != hoursToShow.first {
                                        hoursToShowIndex -= 1
                                    }
                                } else {
                                    if hoursToShow[hoursToShowIndex] != hoursToShow.last {
                                        hoursToShowIndex += 1
                                    }
                                }
                            })
                    )
                
                MainViewDataSourceView()
                
                MainViewInfoView()
            }
            .padding(.bottom, 20)
            
            if showDebug {
                Text(watchState.debugString)
                    .foregroundStyle(.black)
                    .font(.system(size: isSmallScreen ? 12 : 14))
                    .multilineTextAlignment(.leading)
                    .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
                    .background(.teal).opacity(0.9)
                    .cornerRadius(8)
            }
        })
        .frame(maxHeight: .infinity)
        .onReceive(watchState.timer) { date in
            if watchState.updatedDate.timeIntervalSinceNow < -5 {
                watchState.timerControlDate = date
                watchState.requestWatchStateUpdate()
            }
        }
        .onAppear {
            watchState.requestWatchStateUpdate()
        }
        .onTapGesture(count: 5) {
            showDebug = !showDebug
        }
    }
}


// MARK: -  Preview
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
        watchState.isMgDl = false
        watchState.slopeOrdinal = 3
        watchState.deltaValueInUserUnit = 2
        watchState.urgentLowLimitInMgDl = 60
        watchState.lowLimitInMgDl = 80
        watchState.highLimitInMgDl = 140
        watchState.urgentHighLimitInMgDl = 180
        watchState.updatedDate = Date().addingTimeInterval(-120)
        watchState.activeSensorDescription = "Data Source"
        watchState.sensorAgeInMinutes = Double(Int.random(in: 1..<14400))
        watchState.sensorMaxAgeInMinutes = 14400
        watchState.isMaster = false
        watchState.followerDataSourceType = .libreLinkUp
        watchState.followerBackgroundKeepAliveType = .heartbeat
        
        return Group {
            MainView()
        }.environmentObject(watchState)
    }
}
