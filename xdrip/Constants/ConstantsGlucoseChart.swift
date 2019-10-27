import UIKit

enum ConstantsGlucoseChart {
    
    /// default value for glucosechart width in hours
    static let defaultChartWidthInHours = 6.0;
    
    /// default value for timeformat for labels in chart, time axis
    ///
    /// H is hour 24 hour format, "h a" is hour 12 hour format  with a either am or pm
    static let defaultTimeAxisLabelFormat = "H"
    
    /// usually 40.0 mgdl is the lowest value that cgm's give, putting it to 38 guarantees the points will always be visible
    ///
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
    static let axisLineColor = UIColor.black
    
    /// axis line label
    static let axisLabelColor = UIColor.black
    
    /// grid color
    static let gridColor = UIColor.gray
    
    /// glucose color
    static let glucoseTintColor = UIColor.green
    
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

}
