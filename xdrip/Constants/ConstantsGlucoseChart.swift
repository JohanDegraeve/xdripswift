import UIKit

enum ConstantsGlucoseChart {
    
    /// default value for glucosechart width in hours
    static let defaultChartWidthInHours = 6.0;
    
    /// default value for timeformat for labels in chart, time axis
    /// H is hour 24 hour format, "h a" is hour 12 hour format  with a either am or pm
    /// options can be "H", "HH", "HH:00"
    static let defaultTimeAxisLabelFormat = "HH"
    
    /// usually 40.0 mgdl is the lowest value that cgm's give, putting it to 38 guarantees the points will always be visible
    /// only in mgdl because the label will not be shown, hence no bizar values to be shown when going to mgdl
    static let absoluteMinimumChartValueInMgdl = 38.0
    
    /// if there's no readings to show with value higher than the maximum in this array, then this array will determine the maximum possible value in the chart, in mgdl
    static let initialGlucoseValueRangeInMgDl = [50.0, 100.0, 150.0, 200.0]
    
    /// if there's no readings to show with value higher than the maximum in this array, then this array will determine the maximum possible value in the chart, in mmol
    static let initialGlucoseValueRangeInMmol = [3.0, 6.0, 9.0, 12.0]
    
    /// if the maximum in initialGlucoseValueRangeInMgDl isn't enough to show all values, if there's no readings to show with value higher than the maximum in this array, then this array will determine the maximum possible value in the chart, in mgdl
    static let secondGlucoseValueRangeInMgDl = [250.0, 300.0]
    
    /// if the maximum in initialGlucoseValueRangeInMgDl isn't enough to show all values, if there's no readings to show with value higher than the maximum in this array, then this array will determine the maximum possible value in the chart, in mgdl
    static let secondGlucoseValueRangeInMmol = [15.0, 18.0]
    
    /// if the maximum in secondGlucoseValueRangeInMgDl isn't enough to show all values, if there's no readings to show with value higher than the maximum in this array, then this array will determine the maximum possible value in the chart, in mgdl
    static let thirdGlucoseValueRangeInMgDl = [350.0, 400.0]
    
    /// if the maximum in initialGlucoseValueRangeInMgDl isn't enough to show all values, if there's no readings to show with value higher than the maximum in this array, then this array will determine the maximum possible value in the chart, in mgdl
    static let thirdGlucoseValueRangeInMmol = [21.0, 23.0]
    
    /// axis line color    (make white to match new dark UI theme)
    static let axisLineColor = UIColor.darkGray
    
    /// axis line label    (make white to match new dark UI theme)
    static let axisLabelColor = UIColor.white
    
    /// grid color to use if useObjectives is not enabled
    static let gridColor = UIColor.darkGray
    
    /// grid color to use if useObjectives is enabled
    static let gridColorObjectives = UIColor.darkGray.withAlphaComponent(0.4)
    
    // objective/target range guidelines. Will use either standard gray or colored lines
    // make use alpha components to make the perceived brightness of each line be the same to the user (otherwise red appears washed out)
    
    /// color for urgent high and urgent low line, if showColoredObjectives is not enabled
    static let guidelineUrgentHighLow = UIColor.lightGray.withAlphaComponent(0.8)
    
    /// color for urgent high and urgent low line, if showColoredObjectives is not enabled
    static let guidelineHighLow = UIColor.lightGray.withAlphaComponent(1)
    
    /// color for urgent high and urgent low line, if showColoredObjectives is enabled
    static let guidelineUrgentHighLowColor = UIColor.red.withAlphaComponent(0.8)
    
    /// color for high and low line, if showColoredObjectives is enabled
    static let guidelineHighLowColor = UIColor.yellow.withAlphaComponent(0.7)
    
    /// color for target line
    static let guidelineTargetColor = UIColor.green.withAlphaComponent(0.5)
    
    /// glucose colors
    static let glucoseTintColor = UIColor.cyan
    
    /// labels width for vertical axis
    static let yAxisLabelsWidth: CGFloat = 30
    
    /// Empty space in points added to the leading edge of the chart
    static let leading: CGFloat = 0
    
    /// Empty space in points added to the top edge of the chart
    static let top: CGFloat = 8
    
    /// Empty space in points added to the trailing edge of the chart
    static let trailing: CGFloat = 4
    
    /// Empty space in points added to the bottom edge of the chart
    static let bottom: CGFloat = 0
    
    /// The spacing in points between X axis labels and the X axis line
    static let labelsToAxisSpacingX: CGFloat = 6
    
    /// The spacing in points between axis title labels and axis labels
    static let axisTitleLabelsToLabelsSpacing: CGFloat = 0
    
    /// diameter of the circle for blood glucose readings
    static let glucoseCircleDiameter: CGFloat = 6
    
    /// when user pans the chart, when ending the gesture, deceleration is done. At regular intervals the chart needs to be redrawn. This is the interval in seconds
    static let decelerationTimerValueInSeconds = 0.030
    
    /// deceleration rate to use when ending pan gesture on chart
    static let decelerationRate = UIScrollView.DecelerationRate.normal.rawValue
    
    /// maximum amount of elements in the glucoseChartPoints array, this will be limited for performance reasons
    static let maximumElementsInGlucoseChartPointsArray:Int = 1000

    /// dateformat for minutesAgo label when user is panning the chart back in time. The label will show the timestamp of the latest shown value in the chart
    static let dateFormatLatestChartPointWhenPanning = "E d MMM HH:mm"
    
}
