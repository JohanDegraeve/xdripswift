import UIKit

enum ConstantsGlucoseChart {
    
    /// default value for glucosechart width in hours
    static let defaultChartWidthInHours = 6.0;
    
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
    
    // glucose circle/dot color and sizes
    
    /// glucose colors - for values in range
    static let glucoseInRangeColor = UIColor.green
    
    /// glucose colors - for values higher than urgentHighMarkValue or lower than urgent LowMarkValue
    static let glucoseUrgentRangeColor = UIColor.red

    /// glucose colors - for values between highMarkValue and urgentHighMarkValue or between urgentLowMarkValue and lowMarkValue
    static let glucoseNotUrgentRangeColor = UIColor.yellow
    
    /// diameter of the circle for blood glucose readings with a 3h chart width. The more hours on the chart, the smaller the circles should be
    static let glucoseCircleDiameter3h: CGFloat = 7
    
    /// diameter of the circle for blood glucose readings with a 6h chart width. The more hours on the chart, the smaller the circles should be
    static let glucoseCircleDiameter6h: CGFloat = 6
    
    /// diameter of the circle for blood glucose readings with a 12h chart width. The more hours on the chart, the smaller the circles should be
    static let glucoseCircleDiameter12h: CGFloat = 5
    
    /// diameter of the circle for blood glucose readings with a 24h chart width. The more hours on the chart, the smaller the circles should be
    static let glucoseCircleDiameter24h: CGFloat = 4
    
    // calibration circle fill/border color/sizes
    
    /// calibration inner circle color
    static let calibrationCircleColorInner = UIColor.red
    
    /// calibration outer circle color
    static let calibrationCircleColorOuter = UIColor.white
    
    /// calibration outer circle scale factor compared to the chart glucose circle size
    static let calibrationCircleScaleOuter: CGFloat = 1.9
    
    /// calibration inner circle scale factor compared to the chart glucose circle size
    static let calibrationCircleScaleInner: CGFloat = 1.4
    
    // bolus treatment marker color/sizes
    
    /// bolus treament marker colour
    static let bolusTreatmentColor = UIColor.systemBlue
    
    /// how far above the bottom of the chart should the bolus treatment start? 0 would be touching
    static let bolusTreatmentChartPointYAxisOffsetInMgDl: Double = 2
    
    /// how should we scale the bolus values vertically? A value of 5-7 seems to be reasonable to give context to the bolus size without disturbing the rest of the elements
    static let bolusTreatmentChartPointYAxisScaleFactor: Double = 6
    
    /// values below this threshold will be shown as micro-boluses without labels and scaled accordingly
    static let defaultSmallBolusTreamentThreshold: Double = 1.0
    
    /// how much should we scale the size of the micro-bolus triangle compared to the bolus triangle. Should be less than 1 to make them smaller
    static let smallBolusTreamentScale: CGFloat = 0.5
    
    /// triangle size for bolus treatments with a 3h chart width. The more hours on the chart, the smaller the triangles should be.
    static let bolusTriangleSize3h: CGFloat = 20
    
    /// triangle size for bolus treatments with a 6h chart width. The more hours on the chart, the smaller the triangles should be.
    static let bolusTriangleSize6h: CGFloat = 18
    
    /// triangle size for bolus treatments with a 12h chart width. The more hours on the chart, the smaller the triangles should be.
    static let bolusTriangleSize12h: CGFloat = 16
    
    /// triangle size for bolus treatments with a 24h chart width. The more hours on the chart, the smaller the triangles should be.
    static let bolusTriangleSize24h: CGFloat = 14
    
    /// make the triangle height slightly less than the width to prevent it looking too "pointy"
    static let bolusTriangleHeightScale: CGFloat = 0.9
    
    // carb treatment marker color/sizes
    
    /// carbs treament marker colour
    static let carbsTreatmentColor = UIColor.systemOrange
    
    /// threshold below which carbs will be added to the smallCarbs array
    static let smallCarbsTreamentThreshold: CGFloat = 6.0
    
    /// The scale will determine how big the smallCarbs circle is scaled compared to the glucose point size)
    static let smallCarbsTreamentScale: CGFloat = 2.5
    
    /// threshold below which carbs will be added to the mediumCarbs array (if not previously added to another array)
    static let mediumCarbsTreamentThreshold: CGFloat = 15.0
    
    /// The scale will determine how big the mediumCarbs circle is scaled compared to the glucose point size)
    static let mediumCarbsTreamentScale: CGFloat = 3.3
    
    /// threshold below which carbs will be added to the largeCarbs array (if not previously added to another array)
    static let largeCarbsTreamentThreshold: CGFloat = 35.0
    
    /// The scale will determine how big the largeCarbs circle is scaled compared to the glucose point size)
    static let largeCarbsTreamentScale: CGFloat = 4.5
    
    /// The scale will determine how big the veryLargeCarbs circle is scaled compared to the glucose point size)
    static let veryLargeCarbsTreamentScale: CGFloat = 6.6
    
    // bg check circle fill/border color/sizes
    
    /// bg check outer circle color
    static let bgCheckTreatmentColorOuter = UIColor.gray
    
    /// bg check inner circle color
    static let bgCheckTreatmentColorInner = UIColor.red
    
    /// bg check outer circle scale factor compared to the chart glucose circle size
    static let bgCheckTreatmentScaleOuter: CGFloat = 1.9
    
    /// bg check inner circle scale factor compared to the chart glucose circle size
    static let bgCheckTreatmentScaleInner: CGFloat = 1.4
    
    // treatment label font size/color/background

    /// default label settings for the treatments labels. These are set for 6hr chart width - they will be scaled accordingly as needed
    static let treatmentLabelFontSize: Double = 12

    /// treament label font colour
    static let treatmentLabelFontColor = UIColor.white
    
    /// treament label background colour (should have some transparency)
    static let treatmentLabelBackgroundColor = UIColor.black.withAlphaComponent(0.5)
    
    /// additional label separation (in mg/dl) when using mmol/l (needed due to the scaling/conversion)
    static let treatmentLabelMmolOffset: Double = 2
    
    /// how far should the label be separated from the bolus marker by default
    static let mediumBolusLabelSeparation: Double = 7
    
    /// how far should the label be separated from the smallCarbs marker by default
    static let smallCarbsLabelSeparation: Double = 7
    
    /// how far should the label be separated from the mediumCarbs marker by default
    static let mediumCarbsLabelSeparation: Double = 8
    
    /// how far should the label be separated from the largeCarbs marker by default
    static let largeCarbsLabelSeparation: Double = 10
    
    /// how far should the label be separated from the veryLargeCarbs marker by default
    static let veryLargeCarbsLabelSeparation: Double = 12
    
    // chart format parameters
    
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
    
    /// when user pans the chart, when ending the gesture, deceleration is done. At regular intervals the chart needs to be redrawn. This is the interval in seconds
    static let decelerationTimerValueInSeconds = 0.030
    
    /// deceleration rate to use when ending pan gesture on chart
    static let decelerationRate = UIScrollView.DecelerationRate.normal.rawValue
    
    /// maximum amount of elements in the glucoseChartPoints array, this will be limited for performance reasons
    static let maximumElementsInGlucoseChartPointsArray:Int = 1000

    /// dateformat for minutesAgo label when user is panning the chart back in time. The label will show the timestamp of the latest shown value in the chart
    static let dateFormatLatestChartPointWhenPanning = "E d MMM jj:mm"
    
    /// dateformat for the date label in the 24 hours static landscape chart
    static let dateFormatLandscapeChart = "EEEE dd/MM/yyyy"
    
    /// the amount of hours of bg readings that the mini-chart should show (first range)
    static let miniChartHoursToShow1: Double = 24
    
    /// the amount of hours of bg readings that the mini-chart should show (second range)
    static let miniChartHoursToShow2: Double = 48
    
    /// the amount of hours of bg readings that the mini-chart should show (third range)
    static let miniChartHoursToShow3: Double = 72
    
    /// the amount of hours of bg readings that the mini-chart should show (fourth range)
    static let miniChartHoursToShow4: Double = 168
    
    /// tthe standard alpha value of the label. It should be less than one in order to make it more greyed out
    static let miniChartHoursToShowLabelAlpha: Double = 0.4
    
    /// the size of the glucose circles used in the mini-chart
    static let miniChartGlucoseCircleDiameter: CGFloat = 3
    
    /// color for high and urgent low lines in the mini-chart
    static let guidelineMiniChartHighLowColor = UIColor.white
    
}
