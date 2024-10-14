//
//  MainViewDataSourceView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 21/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

struct MainViewDataSourceView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    let isSmallScreen = WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen ? true : false
    
    var body: some View {
        VStack(spacing: 2) {
            
            let textSize: CGFloat = isSmallScreen ? 12 : 14
            
            if (watchState.activeSensorDescription != "" || watchState.sensorAgeInMinutes > 0) || !watchState.isMaster {
                
                ProgressView(value: Float(watchState.activeSensorProgress().progress))
                    .tint(ConstantsHomeView.sensorProgressViewNormalColorSwiftUI)
                    .scaleEffect(x: 1, y: 0.3, anchor: .center)
                
                HStack(alignment: .center) {
                    if !watchState.isMaster {
                        HStack(alignment: .center, spacing: isSmallScreen ? 2 : 4) {
                            watchState.getFollowerConnectionNetworkStatus().image
                                .font(.system(size: textSize))
                                .foregroundStyle(watchState.getFollowerConnectionNetworkStatus().color)
                            
                            watchState.followerBackgroundKeepAliveType.keepAliveImage
                                .font(.system(size: textSize))
                                .foregroundStyle(watchState.getFollowerBackgroundKeepAliveColor())
                            
                            Text(watchState.followerDataSourceType.fullDescription)
                                .font(.system(size: textSize)).fontWeight(.semibold)
                                .minimumScaleFactor(0.2)
                        }
                    } else {
                        Text(watchState.activeSensorDescription)
                            .font(.system(size: textSize)).fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if watchState.sensorAgeInMinutes > 0 {
                        Text(watchState.sensorAgeInMinutes.minutesToDaysAndHours())
                            .font(.system(size: textSize))
                            .foregroundStyle(watchState.activeSensorProgress().textColor)
                    }
                }
                .padding([.leading, .trailing], isSmallScreen ? 6 : 8)
            } else {
                ProgressView(value: 0)
                    .tint(ConstantsHomeView.sensorProgressViewNormalColorSwiftUI)
                    .scaleEffect(x: 1, y: 0.3, anchor: .center)
                
                HStack {
                    Text(" ⚠️  " + Texts_HomeView.noDataSourceConnectedWatch)
                        .font(.system(size: textSize)).bold()
                    
                    Spacer()
                }
                .padding([.leading, .trailing], 10)
            }
        }
    }
}

struct MainViewDataSourceView_Previews: PreviewProvider {
    
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
        watchState.updatedDate = Date().addingTimeInterval(-400)
        watchState.activeSensorDescription = "Data Source"
        watchState.sensorAgeInMinutes = 0
        watchState.sensorMaxAgeInMinutes = 14400
        watchState.isMaster = false
        watchState.followerDataSourceType = .libreLinkUp
        watchState.secondsUntilFollowerDisconnectWarning = 60 * 7
        watchState.timeStampOfLastFollowerConnection = Date().addingTimeInterval(-60 * 6)
        
        return Group {
            MainViewDataSourceView()
        }.environmentObject(watchState)
    }
}
