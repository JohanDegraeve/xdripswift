//
//  MainViewDataSourceView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 21/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

#if canImport(WatchKit)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#endif

struct MainViewDataSourceView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    let isSmallScreen = {
        #if canImport(WatchKit)
        return WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen
        #elseif canImport(UIKit)
        return UIScreen.main.bounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen
        #else
        return false
        #endif
    }()
    
    var body: some View {
        VStack(spacing: 2) {
            let textSize: CGFloat = isSmallScreen ? 12 : 14
            
            if (watchState.activeSensorDescription != "" || watchState.sensorAgeInMinutes > 0) || !watchState.isMaster {
                sensorLifetimeProgressView
                
                ScaledDataSourceRow(height: isSmallScreen ? 20 : 22) {
                    if !watchState.isMaster {
                        HStack(alignment: .center, spacing: isSmallScreen ? 2 : 4) {
                            Circle()
                                .fill(watchState.followerConnectionIndicatorColor())
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle()
                                        .stroke(watchState.followerConnectionIndicatorColor().opacity(0.35), lineWidth: 3)
                                }

                            watchState.followerBackgroundKeepAliveType.keepAliveImage
                                .font(.system(size: textSize))
                                .foregroundStyle(watchState.getFollowerBackgroundKeepAliveColor())

                            Text(watchState.followerDataSourceType.shortDescription)
                                .font(.system(size: textSize)).fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    } else {
                        HStack(alignment: .center, spacing: isSmallScreen ? 2 : 4) {
                            if let sensorNoiseIndicatorColor = watchState.sensorNoiseIndicatorColor() {
                                Circle()
                                    .fill(sensorNoiseIndicatorColor)
                                    .frame(width: 8, height: 8)
                                    .overlay {
                                        Circle()
                                            .stroke(sensorNoiseIndicatorColor.opacity(0.35), lineWidth: 3)
                                    }
                                    .accessibilityLabel(watchState.sensorNoiseIndicatorAccessibilityLabel())
                            }

                            Text(watchState.activeSensorDescription)
                                .font(.system(size: textSize)).fontWeight(.semibold)
                                .lineLimit(1)

                            if watchState.watchCollectionConfigured {
                                DirectWatchCollectionIcon(symbolSize: 16)
                            }
                        }
                    }
                } trailing: {
                    if watchState.sensorAgeInMinutes > 0 {
                        Text(watchState.activeSensorLifetimeText())
                            .font(.system(size: textSize))
                            .foregroundStyle(watchState.activeSensorProgress().textColor)
                            .lineLimit(1)
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

    private var sensorLifetimeProgressView: some View {
        // use the latest Watch state directly so status and countdown changes
        // update the progress bar without animation
        ProgressView(value: watchState.activeSensorProgress().progress)
            .progressViewStyle(.linear)
            .tint(ConstantsHomeView.sensorProgressViewNormalColorSwiftUI)
            .frame(maxWidth: .infinity)
            .frame(height: 5)
            .scaleEffect(x: 1, y: 0.3, anchor: .center)
            .padding(.vertical, 2)
    }
}

private enum DataSourceRowSide: Hashable {
    case leading, trailing
}

private struct DataSourceRowWidthKey: PreferenceKey {
    static var defaultValue: [DataSourceRowSide: CGFloat] = [:]

    static func reduce(value: inout [DataSourceRowSide: CGFloat], nextValue: () -> [DataSourceRowSide: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Fit both ends of the line at one scale while keeping sensor age at the trailing edge.
struct ScaledDataSourceRow<Leading: View, Trailing: View>: View {
    let height: CGFloat
    let leading: Leading
    let trailing: Trailing
    @State private var widths: [DataSourceRowSide: CGFloat] = [:]

    init(height: CGFloat, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.height = height
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { available in
            let leadingWidth = widths[.leading] ?? 0
            let trailingWidth = widths[.trailing] ?? 0
            let gap: CGFloat = trailingWidth > 0 ? 6 : 0
            let naturalWidth = leadingWidth + trailingWidth + gap
            let scale = available.size.width > 0 && naturalWidth > 0
                ? min(1, available.size.width / naturalWidth) : 1

            HStack(spacing: 0) {
                leading
                    .fixedSize(horizontal: true, vertical: false)
                    .background {
                        GeometryReader { measured in
                            Color.clear.preference(key: DataSourceRowWidthKey.self, value: [.leading: measured.size.width])
                        }
                    }

                Spacer(minLength: gap)

                trailing
                    .fixedSize(horizontal: true, vertical: false)
                    .background {
                        GeometryReader { measured in
                            Color.clear.preference(key: DataSourceRowWidthKey.self, value: [.trailing: measured.size.width])
                        }
                    }
            }
            .frame(width: available.size.width / scale)
            .scaleEffect(scale, anchor: .leading)
            .frame(width: available.size.width, height: available.size.height, alignment: .leading)
        }
        .frame(height: height)
        .onPreferenceChange(DataSourceRowWidthKey.self) { measured in
            if measured != widths { widths = measured }
        }
    }
}

/// Glucose pages show collection status. Phone communication stays in Connection details.
struct DirectWatchCollectionIcon: View {
    @EnvironmentObject var watchState: WatchStateModel
    var symbolSize: CGFloat = 16

    var body: some View {
        if watchState.watchCollectionConfigured {
            TimelineView(.periodic(from: .now, by: 2)) { timeline in
                let status = watchState.directWatchCollector.isPaused ? .paused : watchReadingStatus(at: timeline.date)
                Image(systemName: ConstantsDirectWatch.watchSymbol(for: status))
                    .foregroundStyle(ConstantsDirectWatch.statusColor(for: status))
                    .accessibilityLabel(status.title)
                    .font(.system(size: symbolSize))
            }
        }
    }

    private func watchReadingStatus(at date: Date) -> DirectWatchReadingStatus {
        guard watchState.directWatchCollector.configuration != nil else { return .suspended }
        let lastReading = watchState.directWatchCollector.latestReadingAt
        return DirectWatchReadingStatus(isConfigured: true, isSuspended: false, latestReadingAt: lastReading, now: date,
                                        resumedAt: watchState.directWatchCollector.collectionResumedAt,
                                        lastConnectedAt: watchState.directWatchCollector.lastConnectedAt)
    }
}

/// Scale the whole row, including SF Symbols, at one ratio without truncating its text.
struct UniformlyScaledWatchRow<Content: View>: View {
    let height: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var naturalWidth: CGFloat = 0

    var body: some View {
        GeometryReader { available in
            let scale = naturalWidth > 0 ? min(1, available.size.width / naturalWidth) : 1
            content()
                .fixedSize(horizontal: true, vertical: false)
                .background {
                    GeometryReader { measured in
                        Color.clear.preference(key: WatchRowNaturalWidthKey.self, value: measured.size.width)
                    }
                }
                .scaleEffect(scale)
                .frame(width: available.size.width, height: available.size.height, alignment: .center)
        }
        .frame(height: height)
        .onPreferenceChange(WatchRowNaturalWidthKey.self) { naturalWidth = $0 }
    }
}

private struct WatchRowNaturalWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
        var bgValueArray: [Double] = Array(repeating: 0, count: 144)
        var currentValue: Double = 120
        var increaseValues = true
        
        for index in bgValueArray.indices {
            let randomValue = Double(Int.random(in: -10 ..< 30))
            
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
