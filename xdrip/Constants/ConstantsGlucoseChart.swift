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
    
    /// axis line color
    static let axisLineColor = UIColor.gray
    
    /// axis line label
    static let axisLabelColor = UIColor.white
    
    /// axis line label for objective values
    static let axisLabelColorObjectives = UIColor.white
    
    /// axis line label the target value if needed
    static let axisLabelColorTarget = UIColor.green.withAlphaComponent(0.5)
    
    /// axis line label for dimmed secondary values (non-objective values)
    static let axisLabelColorDimmed = UIColor.gray
    
    /// axis line label for any values that we don't need to display
    static let axisLabelColorHidden = UIColor.clear
    
    /// grid color to use if useObjectives is not enabled
    static let gridColor = UIColor.darkGray
    
    /// grid color to use if useObjectives is enabled
    static let gridColorObjectives = UIColor.darkGray.withAlphaComponent(0.5)
    
    // objective/target range guidelines. Will use either standard gray or colored lines
    // make use alpha components to make the perceived brightness of each line be the same to the user (otherwise red appears washed out)
    
    /// color for urgent high and urgent low line
    static let guidelineUrgentHighLow = UIColor.lightGray
    
    /// color for high and low line
    static let guidelineHighLow = UIColor.white.withAlphaComponent(0.7)
    
    /// color for target line
    static let guidelineTargetColor = UIColor.green.withAlphaComponent(0.3)
    
    /// glucose colors - for values in range
    static let glucoseInRangeColor = UIColor.green
    
    /// glucose colors - for values higher than urgentHighMarkValue or lower than urgent LowMarkValue
    static let glucoseUrgentRangeColor = UIColor.red

    /// glucose colors - for values between highMarkValue and urgentHighMarkValue or between urgentLowMarkValue and lowMarkValue
    static let glucoseNotUrgentRangeColor = UIColor.yellow
    
    /// calibration circle color (inside circle)
    static let calibrationInsideColor = UIColor.red
    
    /// calibration circle border color (outside circle)
    static let calibrationOutsideColor = UIColor.white

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
    
    /// diameter of the circle for blood glucose readings. The more hours on the chart, the smaller the circles should be
    static let glucoseCircleDiameter3h: CGFloat = 7
    static let glucoseCircleDiameter6h: CGFloat = 6
    static let glucoseCircleDiameter12h: CGFloat = 5
    static let glucoseCircleDiameter24h: CGFloat = 4
    
    /// diameter of the circle for calibration chart points (outer circle)
    static let calibrationCircleScaleOuter: CGFloat = 1.9
    
    /// diameter of the circle for calibration chart points (inner circle)
    static let calibrationCircleScaleInner: CGFloat = 1.4
    
    /// when user pans the chart, when ending the gesture, deceleration is done. At regular intervals the chart needs to be redrawn. This is the interval in seconds
    static let decelerationTimerValueInSeconds = 0.030
    
    /// deceleration rate to use when ending pan gesture on chart
    static let decelerationRate = UIScrollView.DecelerationRate.normal.rawValue
    
    /// maximum amount of elements in the glucoseChartPoints array, this will be limited for performance reasons
    static let maximumElementsInGlucoseChartPointsArray:Int = 1000

    /// dateformat for minutesAgo label when user is panning the chart back in time. The label will show the timestamp of the latest shown value in the chart
    static let dateFormatLatestChartPointWhenPanning = "E d MMM HH:mm"
    
}
