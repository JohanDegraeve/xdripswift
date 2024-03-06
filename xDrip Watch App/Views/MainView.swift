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
    
    // set timer to automatically refresh the view
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-a-timer-with-swiftui
    let timer = Timer.publish(every: 7, on: .main, in: .common).autoconnect()
    
    // get the array of different hour ranges from the constants file
    // we'll move through this array as the user swipes left/right on the chart
    let hoursToShow: [Double] = ConstantsAppleWatch.hoursToShow
    
    @State private var currentDate = Date.now
    @State private var hoursToShowIndex: Int = ConstantsAppleWatch.hoursToShowDefaultIndex
    
    // MARK: -  Body
    var body: some View {
        VStack {
            HeaderView()
                .padding([.leading, .trailing], 5)
                .padding([.top], 20)
                .padding([.bottom], -10)
                .onTapGesture(count: 2) {
                    watchState.requestWatchStateUpdate()
                }
            ZStack(alignment: Alignment(horizontal: .center, vertical: .top), content: {
                
                GlucoseChartView(glucoseChartType: .watchApp, bgReadingValues: watchState.bgReadingValues, bgReadingDates: watchState.bgReadingDates, isMgDl: watchState.isMgDl, urgentLowLimitInMgDl: watchState.urgentLowLimitInMgDl, lowLimitInMgDl: watchState.lowLimitInMgDl, highLimitInMgDl: watchState.highLimitInMgDl, urgentHighLimitInMgDl: watchState.urgentHighLimitInMgDl, liveActivitySize: nil, hoursToShowScalingHours: hoursToShow[hoursToShowIndex], glucoseCircleDiameterScalingHours: 4)
                    .padding(.top, 3)
                    .padding(.bottom, 3)
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
                
                if !watchState.isMaster && watchState.followerBackgroundKeepAliveType == .disabled {
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.black)
                            .font(.system(size: 20))
                            .padding(2)
                        Text("Watch App not available")
                            .foregroundStyle(.black)
                            .font(.footnote).bold()
                            .multilineTextAlignment(.center)
                            .padding(2)
                        Text("Follower keep-alive is disabled")
                            .foregroundStyle(.black)
                            .font(.footnote).bold()
                            .multilineTextAlignment(.center)
                            .padding(2)
                    }
                    .background(.red).opacity(0.9)
                    .cornerRadius(6)
                }
                
                if watchState.showAppleWatchDebug {
                    Text(watchState.debugString)
                        .foregroundStyle(.black)
                        .font(.footnote).bold()
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                        .background(.teal).opacity(0.9)
                        .cornerRadius(6)
                        .padding(.top, 10)
                        .padding(.leading, 2)
                }
            })
            
            Spacer()
            
            DataSourceView()
            
            InfoView()
        }
        .padding(.bottom, 20)
        .onReceive(timer) { date in
            currentDate = date
            watchState.requestWatchStateUpdate()
        }
        .onAppear {
            watchState.requestWatchStateUpdate()
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
        watchState.isMgDl = true
        watchState.slopeOrdinal = 5
        watchState.deltaChangeInMgDl = -2
        watchState.urgentLowLimitInMgDl = 60
        watchState.lowLimitInMgDl = 80
        watchState.highLimitInMgDl = 140
        watchState.urgentHighLimitInMgDl = 180
        watchState.updatedDate = Date().addingTimeInterval(-120)
        watchState.activeSensorDescription = "Data Source"
        watchState.sensorAgeInMinutes = Double(Int.random(in: 1..<14400))
        watchState.sensorMaxAgeInMinutes = 14400
        watchState.showAppleWatchDebug = false
        watchState.isMaster = false
        watchState.followerBackgroundKeepAliveType = .normal
        
        return Group {
            MainView()
        }.environmentObject(watchState)
    }
}
