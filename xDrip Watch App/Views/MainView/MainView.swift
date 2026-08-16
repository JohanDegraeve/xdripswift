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

    // the AGP page intentionally reuses this exact view. Only the chart background changes so the
    // layout does not move when swiping between the normal and AGP pages
    let showsAGPBackground: Bool

    // get the array of different hour ranges from the constants file
    // we'll move through this array as the user swipes left/right on the chart
    let hoursToShow: [Double] = ConstantsAppleWatch.hoursToShow

    @Binding var hoursToShowIndex: Int

    // store a boolean flag. We'll toggle this to refresh as needed
    @State private var refreshView = false

    // keep the chart range stable during each render pass so glucose and AGP use the same x-axis
    @State private var chartRangeEndDate = Date()

    // store the height of the non-chart rows so we can give all remaining vertical space to the chart
    @State private var fixedRowHeights: [MainViewFixedRow: CGFloat] = [:]

    private let rowSpacing: CGFloat = 2

    // pull the view back up towards the fixed watchOS time area
    // this offsets the extra top space added after removing the previous ZStack layout
    private let headerTopPadding: CGFloat = -20

    // watchOS reports the SwiftUI container height excluding some system areas
    // use the physical screen height minus a safe reserve so the chart can still fill the usable space
    private let systemReservedHeight: CGFloat = 50

    // prevent the chart from collapsing completely if SwiftUI reports incomplete row measurements
    private let minimumChartHeight: CGFloat = 45

    // GlucoseChartView adds a small trailing x-axis span so the latest point is not clipped
    // map AGP across the same span so the background reaches the chart edge too
    private let chartTrailingAGPExtension: TimeInterval = 5 * 60

    init(showsAGPBackground: Bool = false, hoursToShowIndex: Binding<Int> = .constant(ConstantsAppleWatch.hoursToShowDefaultIndex)) {
        self.showsAGPBackground = showsAGPBackground
        _hoursToShowIndex = hoursToShowIndex
    }

    // MARK: -  Body
    var body: some View {
        GeometryReader { container in
            // use whichever height is larger so the layout fills the watch face on different watch sizes
            let contentHeight = max(container.size.height, ConstantsAppleWatch.screenHeight() - systemReservedHeight)
            let chartHeight = chartHeight(containerHeight: contentHeight)
            let chartStartDate = chartRangeEndDate.addingTimeInterval(-hoursToShow[hoursToShowIndex] * 60 * 60)
            let agpEndDate = chartRangeEndDate.addingTimeInterval(chartTrailingAGPExtension)

            // only the AGP page asks for AGP points. The normal page passes nil so the chart is
            // rendered exactly as a normal glucose chart.
            let agpBackgroundPoints = showsAGPBackground ? watchState.agpBackgroundPointsMatching(startDate: chartStartDate, endDate: agpEndDate) : nil

            VStack(spacing: rowSpacing) {
                MainViewHeaderView()
                    .padding([.leading, .trailing], 5)
                    .padding([.top], headerTopPadding)
                    // keep the header at its natural height and let the chart take any extra space
                    .fixedSize(horizontal: false, vertical: true)
                    .measureFixedRow(.header)
                    .id(refreshView)
                    .onTapGesture(count: 2) {
                        watchState.updateMainViewDate = Date()
                        watchState.requestWatchStateUpdate()
                    }

                if watchState.aidStatusIconImage() != nil {
                    MainViewAIDStatusView()
                        .padding([.leading,], 0)
                        .padding([.trailing], 10)
                        .padding([.top], 2)
                        .padding([.bottom], 6)
                        .fixedSize(horizontal: false, vertical: true)
                        .measureFixedRow(.aidStatus)
                }

                GlucoseChartView(glucoseChartType: watchState.aidStatusIconImage() == nil ? .watchApp : .watchAppWithAIDStatus, bgReadingValues: watchState.bgReadingValues, bgReadingDates: watchState.bgReadingDates, agpBackgroundPoints: agpBackgroundPoints, agpBackgroundOpacityMultiplier: showsAGPBackground ? ConstantsGlucoseChartSwiftUI.agpOpacityMultiplierWatchApp : nil, explicitVisibleEndDate: chartRangeEndDate, isMgDl: watchState.isMgDl, urgentLowLimitInMgDl: watchState.urgentLowLimitInMgDl, lowLimitInMgDl: watchState.lowLimitInMgDl, highLimitInMgDl: watchState.highLimitInMgDl, urgentHighLimitInMgDl: watchState.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: hoursToShow[hoursToShowIndex], glucoseCircleDiameterScalingHours: 4, overrideChartHeight: chartHeight, overrideChartWidth: container.size.width, highContrast: nil)
                    // make the full chart rectangle respond to swipes, not only the visible chart marks
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 80, coordinateSpace: .local)
                            .onEnded({ value in
                                if value.startLocation.x > value.location.x {
                                    if hoursToShow[hoursToShowIndex] != hoursToShow.first {
                                        hoursToShowIndex -= 1
                                        // refresh the chart end date so both glucose and AGP use the new range immediately
                                        chartRangeEndDate = Date()
                                    }
                                } else if hoursToShow[hoursToShowIndex] != hoursToShow.last {
                                    hoursToShowIndex += 1
                                    // refresh the chart end date so both glucose and AGP use the new range immediately
                                    chartRangeEndDate = Date()
                                }
                            })
                    )

                MainViewDataSourceView()
                    .fixedSize(horizontal: false, vertical: true)
                    .measureFixedRow(.dataSource)

                MainViewInfoView()
                    .fixedSize(horizontal: false, vertical: true)
                    .measureFixedRow(.info)
            }
            .frame(width: container.size.width, height: contentHeight, alignment: .top)
            // update the chart height as soon as SwiftUI has measured the fixed rows
            .onPreferenceChange(MainViewFixedRowHeightPreferenceKey.self) { fixedRowHeights = $0 }
            .onReceive(watchState.timer) { date in
                if watchState.updatedDate.timeIntervalSinceNow < -5 {
                    chartRangeEndDate = date
                    watchState.timerControlDate = date
                    watchState.requestWatchStateUpdate()
                    refreshView.toggle()
                }
            }
            .onAppear {
                chartRangeEndDate = Date()
                // if the Watch session is not reachable yet, the model will keep this request and retry it
                requestAGPBackgroundIfNeeded(endDate: chartRangeEndDate)
                watchState.requestWatchStateUpdate()
                refreshView.toggle()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chartHeight(containerHeight: CGFloat) -> CGFloat {
        // everything except the chart keeps its measured height
        // the chart then fills whatever height remains
        let fixedHeight = fixedRowHeights.values.reduce(0, +)
        let visibleRowCount = watchState.aidStatusIconImage() == nil ? 4 : 5
        let spacingHeight = CGFloat(max(visibleRowCount - 1, 0)) * rowSpacing

        return max(containerHeight - fixedHeight - spacingHeight, minimumChartHeight)
    }

    private func requestAGPBackgroundIfNeeded(endDate: Date) {
        guard showsAGPBackground else { return }

        let startDate = endDate.addingTimeInterval(-hoursToShow[hoursToShowIndex] * 60 * 60)
        let agpEndDate = endDate.addingTimeInterval(chartTrailingAGPExtension)

        // request the compact AGP profile from the iOS app. The Watch maps it onto this date range locally.
        watchState.requestAGPBackground(startDate: startDate, endDate: agpEndDate)
    }
}

private enum MainViewFixedRow: Hashable {
    case header
    case aidStatus
    case dataSource
    case info
}

private struct MainViewFixedRowHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [MainViewFixedRow: CGFloat] = [:]

    static func reduce(value: inout [MainViewFixedRow: CGFloat], nextValue: () -> [MainViewFixedRow: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private extension View {
    func measureFixedRow(_ row: MainViewFixedRow) -> some View {
        background {
            GeometryReader { geometry in
                // use a background preference so measuring the row does not affect the row's layout
                Color.clear.preference(key: MainViewFixedRowHeightPreferenceKey.self, value: [row: geometry.size.height])
            }
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
        watchState.aidStatus = AIDStatus(condition: .active, style: .loop, statusUpdatedAt: Date().addingTimeInterval(-180), lastActivityAt: Date().addingTimeInterval(-125), iob: 2.25, cob: 24, statusTitle: "Looping", staleStatusTitle: "No data")

        return Group {
            MainView()
        }.environmentObject(watchState)
    }
}
