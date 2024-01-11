//
//  SUIHelper.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// `struct` to define the detail of the x-axis of any chart.
final class XAxisManager {
    
    /// Store the lower boundary of the chart
    private (set) var chartLowerBound: Date = Date()
    
    /// Store the upper boundary of the chart
    private (set) var chartUpperBound: Date = Date().addingTimeInterval(60.0)
    
    /// The width of the view we're plotting in
    private(set) var width: CGFloat = 400
    
    func setChartDetails(lowerBound start: Date? = nil, upperBound end: Date? = nil, viewWidth width: CGFloat? = nil) {
        self.width = width ?? self.width
        self.chartLowerBound = start ?? self.chartLowerBound
        self.chartUpperBound = end ?? self.chartUpperBound
        recalc()
    }
    
    /// Set the upper and lower bounds to the  reference date for AGP charts
    func setAGPBounds() -> some View {
        self.chartLowerBound = Date.init(timeIntervalSinceReferenceDate: 0.0)
        self.chartUpperBound = Date.init(timeIntervalSinceReferenceDate: 0.0).addingTimeInterval(86400)
        recalc()
        return EmptyView()
    }
    
    /// This iVar will indicate the number of markers on a chart
    /// in order to plot a reasonably uncrowded line.
    private (set) var markerCount: Int = 1
    
    /// Store the time span that this chart covers (in seconds)
    private (set) var chartSpan: TimeInterval = 3600
    
    // Each time the lower and upper bounds are altered then we recalculate the iVars needed to render the chart
    private func recalc() {
        chartSpan = max(0, chartUpperBound.timeIntervalSince(chartLowerBound))
        
        if chartSpan > 604800 { // a week
            markerCount = Int(chartSpan / 604800)// << marker for each week
        } else if chartSpan > 86400 { // a day
            markerCount = Int(chartSpan / 86400) // marker for each day
        } else if chartSpan > 43200 { // 12 hours
            markerCount = Int(chartSpan / 21600) // marker every 6 hours
        } else if chartSpan > 3600 { // << 1 hour
            markerCount =  Int(chartSpan / 3600) // << marker every hour
        } else {
            markerCount = Int(chartSpan / 600) // << marker every 10 mins
        }
    }

    /// Get the x-position of a date
    func xCoord(of date: Date, inViewWidth width: CGFloat) -> CGFloat {
        return width * fractionAcross(of: date, inViewWidth: width)
    }
    
    /// Get the fraction of a date across the x-axis
    func fractionAcross(of date: Date, inViewWidth width: CGFloat) -> CGFloat {
        return min(1.0, date.timeIntervalSince(chartLowerBound) / chartSpan)
    }
    
    func getDate(from x: CGFloat, in width: CGFloat) -> Date {
        let fractionAcross: CGFloat = x / width
        let offset: CGFloat = chartSpan * fractionAcross
        return chartLowerBound.addingTimeInterval(TimeInterval(offset))
    }
}



/// `struct` to define the detail of the y-axis of any chart..
final class YAxisManager {
    
    /// Store the lower boundary of the chart
    var chartLowerBound: UniversalBGLevel = UniversalBGLevel(mmoll: 1.0) {
        didSet {
            recalc()
        }
    }
    
    /// Store the upper boundary of the chart
    var chartUpperBound: UniversalBGLevel = UniversalBGLevel(mmoll: 30.0) {
        didSet {
            recalc()
        }
    }
    
    private var gamma: CGFloat = 1/2.6
    
    /// Store the result values span (**mmoll !!!**)
    private (set) var span: Double = 29.0
    
    /// Recalculate the span of the chart if it's upper or lower bounds are altered.
    ///
    /// These are arbitrarily done in mmol/l
    private func recalc() {
        span = chartUpperBound.mmoll.value - chartLowerBound.mmoll.value
    }
    
    /// Returns a normalised y coord for a given BG level
    ///
    /// The return value a point on a sine wave so that it is weighted
    /// towards the in range values rather than linear (out = in).
    /// The theory is that the urgent low range is the narrowest (0 ...< 3.0),
    /// but the urgent high range is the widest (13.0+). Giving more screen area to the
    /// in range and low ranges would be helpful.
    func chartResponseCurve(for level: UniversalBGLevel) -> CGFloat {
        
        // get normailsed value of the level
        let x: CGFloat = CGFloat(min(chartUpperBound.mmoll.value, (max(chartLowerBound.mmoll.value, level.mmoll.value)))) / span
        // Get a fraction of PI (x-axis is effectively 0 ... (PI / 2) so that a sine function will return 0 ... 1)
        let piFraction: CGFloat = (min(1.0, x + 0.05)) * (CGFloat.pi / 2) // << offset x a little to shift the graph line a little higher on screen
        
        return sin(piFraction)
    }
    
    func chartResponseCurve(for yCoord: CGFloat, in height: CGFloat) -> CGFloat {
        // Convert the yCoord to a linear mmol/l axis
        let mmollFraction = (yCoord / height) * span
        // Return a normalised (0 ... 1), value of the yCoord that lies on the response curve of the axis
        return chartResponseCurve(for: UniversalBGLevel(mmoll: MMOLL(mmollFraction)))
    }
    
    /// Get the y-position of a result
    func yCoord(of result: UniversalBGLevel, inViewHeight height: CGFloat) -> CGFloat {
        return height - (height * chartResponseCurve(for: result))
    }
    
    /// Returns a `UniversalBGLevel` of the corresponding y coordinate in the view
    func getResult(from y: CGFloat, inViewHeight height: CGFloat) -> UniversalBGLevel {
        // y = h - (h * pow(R, 1.6)), (h * pow(R, 1.6)) = (h - y), pow(R, 1.6) = (h - y) / h, R = pow((h - y) / h, (1 / 1.6))
        let fraction = (height - y) / height
        let inverseResponse = pow(fraction, (1 / gamma))
        return UniversalBGLevel(value: inverseResponse * chartUpperBound.levelInUserUnits)
    }
}

final class SUIViewCoordinateManager {
    
    struct Marker {
        var isMajor: Bool
        var x: CGFloat
        var text: String
    }
    
    init(viewSize: CGSize) {
        self.viewSize = viewSize
    }
    
    let xManager: XAxisManager = XAxisManager()
    let yManager: YAxisManager = YAxisManager()
    
    var viewSize: CGSize {
        didSet {
            // Force recalc of spans
            xManager.setChartDetails(viewWidth: viewSize.width)
            yManager.chartLowerBound = yManager.chartLowerBound
        }
    }
    
    var chartLowerBounds: UniversalBGLevel {
        return yManager.chartLowerBound
    }
    
    var chartUpperBounds: UniversalBGLevel {
        return yManager.chartUpperBound
    }
    
    var chartLeftBounds: CGFloat {
        return 0
    }
    
    var chartRightBounds: CGFloat {
        return xManager.width
    }
    
    /// `DateFormatter` to control display of x-axis markers.
    ///
    /// Set up just the once and is public for use elsewhere.
    var dateFormatter: DateFormatter = DateFormatter()
    
    func setViewSize(size: CGSize) -> some View {
        self.viewSize = size
        return EmptyView()
    }
    
    func coords(for level: UniversalBGLevel, atTimeStamp date: Date? = nil) -> CGPoint {
        let x = xManager.xCoord(of: date ?? level.timestamp, inViewWidth: viewSize.width)
        let y = yManager.yCoord(of: level, inViewHeight: viewSize.height)
        return CGPoint(x: x, y: y)
    }
    
    func resultWithTimeStamp(from point: CGPoint) -> UniversalBGLevel {
        let time = xManager.getDate(from: point.x, in: viewSize.width)
        var level = yManager.getResult(from: point.y, inViewHeight: viewSize.height)
        level.timestamp = time
        return level
    }
    
    func xAxisMarkers() -> [Marker] {
        
        // This array will be populated with markers for the SUI view
        var markers: [Marker] = []
        // The position of a marker
        var xPos: CGFloat = 5.0
        // The time between markers
        let markerTimeSpan: TimeInterval = xManager.chartSpan / TimeInterval(xManager.markerCount)
        // The display size between markers
        let markerViewStride = viewSize.width / CGFloat(xManager.markerCount)
        
        // Decide whether to show time or date
        if xManager.chartSpan > 86490 { // Greater than about a day between markers...?
            dateFormatter.dateStyle =  .short
            dateFormatter.timeStyle = .none
        } else {
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
        }
        
        for i in 0 ... xManager.markerCount {
            markers.append(Marker(isMajor: (i % 5) == 0, x: xPos, text: xManager.chartLowerBound.addingTimeInterval(markerTimeSpan * TimeInterval(i)).dateToStringInUserLocale(using: dateFormatter)))
            xPos += markerViewStride
        }
        return markers
    }
    
    /// Return the text for a date
    func xMarkerText(for date: Date) -> String {
        // Decide whether to show time or date
        if xManager.chartSpan > 86490 { // Greater than about a day between markers...?
            dateFormatter.dateStyle =  .short
            dateFormatter.timeStyle = .none
        } else {
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short
        }
        return date.dateToStringInUserLocale(using: dateFormatter)
    }
    
    func yAxisMarkers() -> [Marker] {
        let yStride: CGFloat = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? 50.0 : 5.0
        let count = Int(viewSize.height / yStride)
        var markers: [Marker] = []
        var yPos: CGFloat = 0.0
        for i in 0 ..< count {
            markers.append(Marker(isMajor: (i % 5) == 0, x: yPos, text: String(format: "%f0.1", i)))
            yPos += yStride
        }
        
        return markers
    }
}

/// Struct to format mini text such as the axis labels
struct axisLabelModifier: ViewModifier {
    var textColour: Color
    var isMajor: Bool = false
    func body(content: Content) -> some View {
        content
            .font(Font(ConstantsUI.MiniFont))
            .foregroundColor(textColour)
            .opacity(isMajor ? 1.0 : 0.7)
    }
}

enum BGChartAxis {
    case x
    case y
}

/// This PreferenceKey will store the widest child view in a View.
///
/// Excellent explanation of `PreferenceKey':
/// https://www.fivestars.blog/articles/preferencekey-reduce/
struct ViewWidthKey: PreferenceKey {
    
    static var defaultValue: CGFloat = 0.0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
        if value < nextValue() {
            value = nextValue()
        }
    }
    
}

// Custom button style for the granularity of the chart
struct ChartButtonStyle: ButtonStyle {
    
    let isHighlighted: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 50.0)
                .fill((isHighlighted ? Color.SelectedColour : Color.UnselectedColour))
                .frame(maxHeight: .infinity)
            
            configuration.label
                .padding(.horizontal, 4.0)
                .padding(.vertical, 3.0)
                .foregroundColor(.black)
                .background(Color.clear)
                .frame(maxWidth: .infinity)
        }.fixedSize(horizontal: false, vertical: true)
    }
}


/// Very minor code for readability
typealias Days = Int

//MARK:  Buttons for stats granularity

/// These are the buttons on screen when the user's looking at statistics.
///
/// These buttons adjust the observed user prefrences for days over which to calculate
/// stats. When they're pressed, they update the `State` ivar `index` which holds the index
/// of the highlighted button. The update to the user preferences automatically kick starts
/// the statistics manager to re-calculate and that in turn cause the charts to be re-drawn.
struct SUIGranularityButtons: View {
    
    // The granularity buttons. The first element is 'today', then the others denote the number of days over which stats are calculated.
    private let buttons:[(days: Int, image: Image)] = [
        (7, Image(systemName: "calendar.circle.fill")),
        (14, Image(systemName: "calendar.circle.fill")),
        (30, Image(systemName: "calendar.circle.fill")),
        (90, Image(systemName: "calendar.circle.fill")),
    ]
    

    
    /// The observed and mutated ivar of the user required days worth of statistics
    @State var selected: Days = 7
    
    // func to style and display
    private func GranularityButton(days: Days, icon: Image? = nil, onTap:(()->Void)? = nil) -> some View {
        
        return HStack(spacing: 3) {
            
            Text("\(days > 1 ? String(days) : "")").font(Font(ConstantsUI.SmallFont))
            
            if icon != nil {
                icon
            }
        }
        .padding(.horizontal, 20.0).padding(.vertical, 5.0)
        .background(selected == days ? Color.SelectedColour : Color.UnselectedColour)
        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 5.0, height: 5.0)))
        .onTapGesture {
            if selected != days { onTap?() }
        }
    }
    
    /// This array of `Int`s controls which buttons can be activated
    @State private var enabledButtons: Set<Days> = .all
    
    public func setEnabledButtons(buttons: Set<Days>) {
        enabledButtons.removeAll()
        enabledButtons = buttons
    }
    
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 10) {
                ForEach(0..<buttons.count, id: \.self){ buttonIndex in
                    GranularityButton(days: buttons[buttonIndex].days, icon: buttons[buttonIndex].image, onTap: {
                        if !enabledButtons.contains(buttons[buttonIndex].days) { return }
                        selected = buttons[buttonIndex].days
                        // Setting this will kickstart a new analysis. This will ripple through to the SwiftUI views
                        UserDefaults.standard.daysToUseStatistics = selected
                    })
                }
            }.frame(maxWidth: proxy.size.width).background(.clear)
        }
    }
}

struct SUIWorkingWheeels: View {
    
    /// Use this to decide the size of the icons
    var size: CGFloat = 200.0
    
    /// Duration of transition on and off of the animation
    let transDuration: Double = 0.15
    
    var isWorking: Bool
    
    var body: some View {
        return ZStack {
            
            RoundedRectangle(cornerSize: CGSize(width: 10.0, height: 10.0))
                .frame(maxWidth: size, maxHeight: size).foregroundColor(.black)
                .scaleEffect(isWorking ? 1.0 : 0.0).animation(.linear(duration: 0.2), value: isWorking)
            
            // Show the Working image and rotate it if isWorking == true.
            Image(uiImage: UIImage(named: "COGS2")!)
                .resizable()
                .frame(width: size - 30, height: size - 30)
                .rotationEffect(Angle(degrees: isWorking ? Double.random(in: 25 ... 360) : 0.0))
                .animation(isWorking ? .linear(duration: Double.random(in: 1...3)).repeatForever(autoreverses: false) : .linear(duration: 0.01).delay(transDuration + 0.2), value: isWorking)
                .scaleEffect(isWorking ? 1.0 : 0.0).animation(.linear(duration: 0.2), value: isWorking)
            
            // Show the Working image and rotate anti-clockwise it if isWorking == true.
            Image(uiImage: UIImage(named: "COGS1")!)
                .resizable()
                .frame(width: size - 30, height: size - 30)
                .rotationEffect(Angle(degrees: isWorking ? -Double.random(in: 30 ... 360) : 0.0))
                .animation(isWorking ? .linear(duration: Double.random(in: 1...3)).repeatForever(autoreverses: false) : .linear(duration: 0.01).delay(transDuration + 0.2), value: isWorking)
                .scaleEffect(isWorking ? 1.0 : 0.0).animation(.linear(duration: 0.2), value: isWorking)
            
        }.drawingGroup()
    }
}
