//
//  File.swift
//  xdrip
//
//  Created by Todd Dalton on 09/02/2024.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// Main view
public struct SUIChartView: View {
    
    //Describes the type of chart to display
    enum ChartType {
        // Ambulatory Glucose Profile
        case AGP
        // Typically used for a day or less worth of results and just creates a straight forward plot of the levels against time.
        case straightPlot
        // Used to plot the median level and a rectangle at each hour to show the full range of levels within that hour.
        //i.e. it may show that at 7am, the user has had reults within the range of 5mmol/l ... 11mmol/l
        case range
    }
    
    /// Descrbes the type of chart to be drawn
    @State var chartType: ChartType = .AGP
    
    /// Used when the user touch begins or ends
    @State private var timeBarOpacity: Bool = false
    /// Used to grab the date across the view where the user touches
    @State private var touchedDate: Date = Date()
    /// The user's touch point
    @State private var touchedPoint: CGPoint = CGPoint.zero
    
    /// This is the statistics manager from the `RootViewController`
    ///
    /// It's an observed object through `Combine` so each time it is
    /// updated a refresh of the pie chart takes place.
    @ObservedObject public var statMan: StatisticsManager
    
    /// This is the iVar that controlls how many samples will be drawn
    var internalGranularity: CGFloat = 24 // < 50 seems to be the  most number of samples so make it 48 as a multiple of 24
    
    /// This is the range of dates (from left to right on the screen) that the chart covers
    var dateRange:Range<Date> = Date.distantPast ..< Date.distantFuture
    
    var stops = [Gradient.Stop]()
    
    /// The opacity of the areas for high, low, in range, etc
    let backgroundAlpha: CGFloat = 0.2
    
    var scale: CGFloat = 1.0
    
    /// The width of the information tab on the timebar.
    ///
    /// Used to work out which side of the time bar the tab should be displayed.
    @State var infoTabWidth: CGFloat = 0.0
    
    let textColour: Color = Color.white
    let backgroundColour: Color = Color.black
    let timeBarColour = Color.white
    let rangeBoxesOpacity: CGFloat = 0.0
    
    var axisManager: SUIViewCoordinateManager = SUIViewCoordinateManager(viewSize: CGSize.zero)
    
    var useMgDl: Bool {
        return UserDefaults.standard.bloodGlucoseUnitIsMgDl
    }
    
    /// Store the users urgent low value for later use
    let urgentLow = (UniversalBGLevel(mgdl: MGDL(UserDefaults.standard.urgentLowMarkValue)))
    /// Store the users  low, value for later use
    let low = (UniversalBGLevel(mgdl: MGDL(UserDefaults.standard.lowMarkValue)))
    /// Store the users high value for later use
    let high = (UniversalBGLevel(mgdl: MGDL(UserDefaults.standard.highMarkValue)))
    /// Store the users urgent high value for later use
    let urgentHigh = (UniversalBGLevel(mgdl: MGDL(UserDefaults.standard.urgentHighMarkValue)))
    /// This is the colour of the AGP areas
    let rangeColour: Color = Color(red: 0.690, green: 0.944, blue: 0.981)
    
    
    // Render the shaded backgrounds for AGP
    @ViewBuilder func renderRanges(with opacity: CGFloat, in viewSize: CGSize) -> some View {
        
        let lineWidth: CGFloat = 2
        ZStack {
            ZStack(alignment: .bottom) {
                
                let urgentLowHeight: CGFloat = axisManager.coords(for: urgentLow).y
                let lowHeight: CGFloat =  axisManager.coords(for: low).y
                let highHeight: CGFloat =  axisManager.coords(for: high).y
                let urgentHighHeight: CGFloat =  axisManager.coords(for: urgentHigh).y
                
                Path { ulp in
                    ulp.move(to: CGPoint(x: 0.0, y: urgentLowHeight))
                    ulp.addLine(to: CGPoint(x: viewSize.width, y: urgentLowHeight))
                }.stroke(Color.rangeColour(from: .urgentLow), lineWidth: lineWidth)
                
                Path { ulp in
                    ulp.move(to: CGPoint(x: 0.0, y: lowHeight))
                    ulp.addLine(to: CGPoint(x: viewSize.width, y: lowHeight))
                }.stroke(Color.rangeColour(from: .low), lineWidth: lineWidth)
                
                Path { ulp in
                    ulp.move(to: CGPoint(x: 0.0, y: highHeight))
                    ulp.addLine(to: CGPoint(x: viewSize.width, y: highHeight))
                }.stroke(Color.rangeColour(from: .high), lineWidth: lineWidth)
                
                Path { ulp in
                    ulp.move(to: CGPoint(x: 0.0, y: urgentHighHeight))
                    ulp.addLine(to: CGPoint(x: viewSize.width, y: urgentHighHeight))
                }.stroke(Color.rangeColour(from: .urgentHigh), lineWidth: lineWidth)
            }
        }
    }
    
    /** Renders the urgent, low, high and urgent high values on the y-axis.
     
     - Parameter geomSize : A size of the geometry of the final view
     
     - Returns: a view containing just the values of the range stops
     */
    @ViewBuilder func yAxisLabels(in height: CGFloat) -> some View {
        
        let textPosition:CGFloat = 20.0
        let padding: CGFloat = 5.0
        let corners:CGFloat = 3.0
        
        HStack {
            Text(String(format:"%0.1f", (urgentHigh.levelInUserUnits.rounded(.awayFromZero))))
                .modifier(axisLabelModifier(textColour: .black))
                .padding(.horizontal, padding)
                .background(Color.rangeColour(from: .urgentHigh))
                .clipShape(RoundedRectangle(cornerRadius: corners))
        }.position(x: textPosition, y: axisManager.yManager.yCoord(of: urgentHigh, inViewHeight: height))
        
        HStack {
            Text(String(format:"%0.1f", (high.levelInUserUnits.value.rounded(.awayFromZero))))
                .modifier(axisLabelModifier(textColour: .black))
                .padding(.horizontal, padding)
                .background(Color.rangeColour(from: .high))
                .clipShape(RoundedRectangle(cornerRadius: corners))
        }.position(x: textPosition, y: axisManager.yManager.yCoord(of: high, inViewHeight: height))
        
        HStack {
            Text(String(format:"%0.1f", (low.levelInUserUnits.rounded(.awayFromZero))))
                .modifier(axisLabelModifier(textColour: .black))
                .padding(.horizontal, padding)
                .background(Color.rangeColour(from: .low))
                .clipShape(RoundedRectangle(cornerRadius: corners))
        }.position(x: textPosition, y: axisManager.yManager.yCoord(of: low, inViewHeight: height))
        
        HStack {
            Text(String(format:"%0.1f", (urgentLow.mmoll.value.rounded(.awayFromZero))))
                .modifier(axisLabelModifier(textColour: .black))
                .padding(.horizontal, padding)
                .background(Color.rangeColour(from: .urgentLow))
                .clipShape(RoundedRectangle(cornerRadius: corners))
        }.position(x: textPosition, y: axisManager.yManager.yCoord(of: urgentLow, inViewHeight: height))
    }
    
    func updateAxisManager(with viewSize: CGSize) -> some View {
        
        switch chartType {
        case .AGP:
            // With an AGP chart, the start and end *date* are irrelevant - the important thing is to start at 00:00 and continue to 23:59.
            axisManager.xManager.setChartDetails(lowerBound: Date.distantPast, // << completely arbitrary
                                                 upperBound: Date.distantPast.addingTimeInterval(86400)) // 24 hours on from the arbitrary lowerBound
        case .straightPlot:
            // TODO: possibly make a line plot for the the main set of bg levels to replace the current SwiftChart........?
            break
            //axisManager.xManager.setChartDetails(lowerBound: statMan.latestStatistics.readingsCohort.first?.timestamp, upperBound: statMan.latestStatistics.readingsCohort.last?.timestamp)
        case .range:
            break
        }
        
        return axisManager.setViewSize(size: viewSize) // << This is a hack that returns an EmptyView()
    }

    /// -------------------- TIMEBAR VIEWS ----------------------
    /// This renders a vertical bar at the `Date` provided
    ///
    /// A `Date` is used since this enables just passing in the
    /// timestamp of the result closest to the user's touch point
    @ViewBuilder func timeBar(at date: Date, inViewSize size: CGSize,  information: [(text: String, quartile: Int)]? = nil) -> some View {
        
        let value = axisManager.xManager.xCoord(of: date, inViewWidth: size.width)
        let width = size.width / CGFloat(statMan.latestRangeBins.count)
        let halfWidth = width / 2
        let timeBar: Path = Path { aPath in
            aPath.move(to: CGPoint(x: value, y: 0.0))
            aPath.addRect(CGRect(origin: CGPoint(x: value, y: 0.0), size: CGSize(width: width, height: size.height)))
        }
        timeBar.fill(style: FillStyle(eoFill: true, antialiased: true)).foregroundColor(Color.white).opacity(0.4).blendMode(.screen)

        Group(content: {
            
            Text(axisManager.xMarkerText(for: date)).modifier(axisLabelModifier(textColour: .white, isMajor: true)).rotationEffect(Angle(degrees: 90))
            
            if let information = information {
                infoBox(information: information).offset(x: (size.width - value - 100.0)  < $infoTabWidth.wrappedValue ? (-$infoTabWidth.wrappedValue / 2) - width: ($infoTabWidth.wrappedValue / 2) + width)
            }
            
        }).position(x: value + halfWidth, y: 50.0)
    }
    
    /// This is the box that's displayed when the user touches the chart
    @ViewBuilder func infoBox(information: [(text: String, quartile: Int)]) -> some View {
        
        @State var vStackWidth: CGFloat = 0.0
        
        VStack(alignment: .leading, spacing: 5.0) {
            ForEach(information, id: \.self.text) { info in
                HStack (spacing: 5.0) {
                    Image(uiImage: UIImage(named: String("Q\(info.quartile)")) ?? UIImage(named: "Average")!)
                        .resizable()
                        .frame(width: 15.0)
                    Text(info.text).fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: 15.0)
                .getItemWidth { newWidth in
                    vStackWidth = newWidth
                    self.infoTabWidth = newWidth
                }
            }.multilineTextAlignment(.center).minimumScaleFactor(0.1)
        }.padding(5)
            .background(Color(white: 0.6, opacity: 1.0)).foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4.0))
            .frame(width: vStackWidth)
    }
    /// --------------------   ----------------------
    
    
    // MARK: - Main `BODY`
    public var body: some View {
        
        if UserDefaults.standard.daysToUseStatistics < 2 {
            // It isn't a valid AGP chart if it's only got one day's worth of data.
            // It's arguable that less than a week isn't useful, but this will cover the main issue of an incorrect graph with only one day
            ZStack {
                VStack {
                    
                    Image(uiImage: UIImage(systemName: "exclamationmark.square.fill")!)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.orange)
                        .frame(maxWidth: 300.0, maxHeight: 300.0)
                    
                    Text("AGP needs more than one day's data.").foregroundStyle(.white)
                }.background(backgroundColour)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(backgroundColour)
        } else {
            GeometryReader { proxy in
                
                // We can only easily set the view size in the helper class like this.
                //It returns an `EmprtyView()` so  will take no part in the final render.
                updateAxisManager(with: proxy.size)
                
                ZStack {
                    
                    axisManager.xManager.setAGPBounds()
                    
                    renderRanges(with: 0.9, in: proxy.size)
                    
                    // Render range lines
                    yAxisLabels(in: proxy.size.height)
                    
                    if statMan.latestRangeBins.count > 0 {
                        // Chart
                        ZStack  {
                            
                            if chartType == .AGP {
                                // ------ Draw an Ambulatory Glucose Profile graph
                                
                                
                                ZStack {
                                    
                                    var q2575: Path = Path()
                                    
                                    var q1090: Path = Path()
                                    
                                    let width = (proxy.size.width / CGFloat(statMan.latestRangeBins.count))
                                    let halfWidth = width / 2
                                    
                                    let q50 = Path { q50path in
                                        
                                        q1090.move(to: axisManager.coords(for: statMan.latestRangeBins.first!.quartiles.Q10))
                                        
                                        q2575.move(to: axisManager.coords(for: statMan.latestRangeBins.first!.quartiles.Q25))
                                        
                                        q50path.move(to: axisManager.coords(for: statMan.latestRangeBins.first!.quartiles.Q50).offset(dx: (halfWidth), dy: 0.0))
                                        
                                        
                                        var q10points:[CGPoint] = Array(repeating: CGPoint.zero, count: statMan.latestRangeBins.count)
                                        var q25points:[CGPoint] = Array(repeating: CGPoint.zero, count: statMan.latestRangeBins.count)
                                        var q75points:[CGPoint] = Array(repeating: CGPoint.zero, count: statMan.latestRangeBins.count)
                                        var q90points:[CGPoint] = Array(repeating: CGPoint.zero, count: statMan.latestRangeBins.count)
                                        
                                        // Draw lower bound of quartiles
                                        for bin in statMan.latestRangeBins.enumerated() {
                                            
                                            let newQ50 = axisManager.coords(for: bin.element.quartiles.Q50).offset(dx: halfWidth)
                                            
                                            q50path.addCurveWithControlPoints(to: newQ50)
                                            
                                            q25points[bin.offset] = axisManager.coords(for: bin.element.quartiles.Q25).offset(dx: halfWidth)
                                            q75points[bin.offset] = axisManager.coords(for: bin.element.quartiles.Q75).offset(dx: halfWidth)
                                            
                                            q10points[bin.offset] = axisManager.coords(for: bin.element.quartiles.Q10).offset(dx: halfWidth)
                                            q90points[bin.offset] = axisManager.coords(for: bin.element.quartiles.Q90).offset(dx: halfWidth)
                                        }
                                        
                                        for i in 0 ..< q10points.count {
                                            q2575.addCurveWithControlPoints(to: q25points[i])
                                            q1090.addCurveWithControlPoints(to: q10points[i])
                                        }
                                        
                                        for i in (0 ..< q10points.count).reversed() {
                                            q2575.addCurveWithControlPoints(to: q75points[i])
                                            q1090.addCurveWithControlPoints(to: q90points[i])
                                        }
                                    }

                                    // Render the wider ranges
                                    Rectangle().foregroundColor(rangeColour)
                                        .opacity(0.3).clipShape(q1090, style: FillStyle(eoFill: false, antialiased: true))
                                        .blendMode(.screen)

                                    // Render the narrower ranges
                                    Rectangle().foregroundColor(rangeColour)
                                        .opacity(0.3).clipShape(q2575, style: FillStyle(eoFill: false, antialiased: true))
                                        .blendMode(.screen)

                                    q50.stroke(Color.white, lineWidth: 2.0)
                                    
                                }.gesture(DragGesture(minimumDistance: 0).onEnded({ value in
                                    timeBarOpacity = false
                                }).onChanged({ value in
                                    timeBarOpacity = true
                                    touchedDate = axisManager.xManager.getDate(from: value.location.x, in: proxy.size.width)
                                    touchedPoint = value.location
                                }))
                            }

                            if timeBarOpacity {
                                
                                let nearest = statMan.latestRangeBins[touchedDate.hour]
                                
                                timeBar(at: nearest.quartiles.Q75.timestamp,
                                        inViewSize: proxy.size,
                                        information: [
                                            (text: nearest.quartiles.Q90.levelInUserUnitsString, quartile: 90),
                                            (text: nearest.quartiles.Q75.levelInUserUnitsString, quartile: 75),
                                            (text: nearest.averageLevel.levelInUserUnitsString, quartile: 0),
                                            (text: nearest.quartiles.Q25.levelInUserUnitsString, quartile: 25),
                                            (text: nearest.quartiles.Q10.levelInUserUnitsString, quartile: 10)
                                            ]
                                ).opacity(timeBarOpacity.rawDoubleValue)
                                
                                let x: CGFloat = touchedPoint.x + (touchedPoint.x > (proxy.size.width / 2) ? -80 : 80)
                                
                                infoBox(information: [
                                    (text: nearest.quartiles.Q50.unitisedString, quartile: 50)
                                    ]
                                ).position(CGPoint(x: x, y: axisManager.coords(for: nearest.quartiles.Q50).y))
                            }
                        }
                    }
                }
                
                //Draw min and max levels at side of screen
                VStack(alignment: .trailing) {
                    Text((useMgDl ? (axisManager.chartUpperBounds).mgdl.unitisedString : axisManager.chartUpperBounds.mmoll.unitisedString))
                        .font(Font(ConstantsUI.MiniFont))
                        .foregroundColor(textColour)
                    
                    Spacer().frame(maxWidth: .infinity)
                    
                    Text((useMgDl ? axisManager.chartLowerBounds.mgdl.unitisedString : axisManager.chartLowerBounds.mmoll.unitisedString))
                        .font(Font(ConstantsUI.MiniFont))
                        .foregroundColor(textColour)
                }.opacity(0.5)
            }
        }
    }
}
