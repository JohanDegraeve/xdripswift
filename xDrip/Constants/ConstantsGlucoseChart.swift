import SwiftUI

enum ConstantsGlucoseChart {
    
    /// default value for glucosechart width in hours
    static let defaultChartWidthInHours = 5.0
    
    /// usually 40.0 mgdl is the lowest value that cgm's give, putting it to 38 guarantees the points will always be visible
    /// only in mgdl because the label will not be shown, hence no bizar values to be shown when going to mgdl
    static let absoluteMinimumChartValueInMgdl: Double = 38
    
    /// what should the x-axis start with then showing the basal render?
    static let minimumChartValueInMgdlWithBasal: Double = -10
    
    /// what should the x-axis start with then showing the basal render whilst in the 24 hour chart?
    /// we should define a different "minimum value" to match the proportions and make the basal visible
    static let minimumChartValueInMgdlWithBasal24hrChart: Double = 0

    // glucose circle/dot color and sizes
    
    /// glucose colors - for values in range
    static let glucoseInRangeColor = Color.green
    
    /// glucose colors - for values higher than urgentHighMarkValue or lower than urgent LowMarkValue
    static let glucoseUrgentRangeColor = Color.red

    /// glucose colors - for values between highMarkValue and urgentHighMarkValue or between urgentLowMarkValue and lowMarkValue
    static let glucoseNotUrgentRangeColor = Color.yellow
    
    /// glucose colors - for original values when post processing is enabled
    static let glucoseOriginalColor = Color(white: 0.3).opacity(0.3)

    /// glucose colors - for original values when peek mode is active
    static let glucoseOriginalPeekColor = Color(white: 0.5)

    // bolus treatment marker color/sizes
    
    /// bolus Treatment marker colour
    static let bolusTreatmentColor = Color.blue

    /// Long-acting injections use a pink double triangle and sit further below the glucose curve.
    static let basalInjectionTreatmentColor = GlucoseChartTreatmentStyle.basalInjectionColor
    static let basalInjectionOffsetMultiplier: Double = 2.2
    
    static let defaultSmallBolusTreatmentThreshold: Double = 1.0
    
    /// Bolus chart labels are hidden below this dose, independently of dynamic symbol size.
    static let minimumBolusLabelValue: Double = 0.8

    // carb treatment marker color/sizes
    
    /// carbs Treatment marker colour
    static let carbsTreatmentColor = Color.orange
    
    /// Carb chart labels are hidden below this amount, independently of dynamic symbol size.
    static let minimumCarbsLabelValue: Double = 5

    // bg check circle fill/border color/sizes
    
    /// bg check outer circle color
    static let bgCheckTreatmentColorOuter = Color.gray
    
    /// bg check inner circle color
    static let bgCheckTreatmentColorInner = Color.red
    
    /// bg check outer circle scale factor compared to the chart glucose circle size
    static let bgCheckTreatmentScaleOuter: CGFloat = 1.9
    
    /// bg check inner circle scale factor compared to the chart glucose circle size
    static let bgCheckTreatmentScaleInner: CGFloat = 1.4

    /// note treatment color
    static let noteTreatmentColor = Color(white: 0.9)

    // basal rate treatment color

    /// bolus Treatment color
    static let basalTreatmentColor = Color.mint

    /// the amount of days we should use to calculate the max basal rate to allow scaling. It should be enough to allow casual scrolling back 1-2 days without forcing a re-scale
    static let basalScaleDaysForCalculation: Double = 1

    /// Visual width of one native automatic-basal delivery on the glucose chart.
    static let automaticBasalPulseDisplayDuration: TimeInterval = 150
    
    /// amount (in mg/dL) the treatments marker be offset above/below the BG value marker
    static let defaultOffsetTreatmentPositionFromBgMarker: Double = 18

    /// Give dynamically sized carb and bolus symbols more clearance above and below the glucose curve.
    static let doseTreatmentOffsetMultiplier: Double = 1.6

    /// Note labels anchor at the glucose value with only the annotation spacing above it.
    static let noteLabelOffsetMultiplier: Double = 0

    // chart format parameters

    /// when user pans the chart, when ending the gesture, deceleration is done. At regular intervals the chart needs to be redrawn. This is the interval in seconds
    static let decelerationTimerValueInSeconds = 0.030
    
    /// deceleration rate to use when ending pan gesture on chart
    static let decelerationRate = 0.998

    /// dateformat for minutesAgo label when user is panning the chart back in time. The label will show the timestamp of the latest shown value in the chart
    static let dateFormatLatestChartPointWhenPanning = "E d MMM jj:mm"
    
    /// dateformat for the date label in the 24 hours static landscape chart
    static let dateFormatLandscapeChart = "dd/MM/yyyy EEEE"
    
    /// the amount of hours of bg readings that the mini-chart should show (first range)
    static let miniChartHoursToShow1: Double = 24
    
    /// the amount of hours of bg readings that the mini-chart should show (second range)
    static let miniChartHoursToShow2: Double = 48
    
    /// the amount of hours of bg readings that the mini-chart should show (third range)
    static let miniChartHoursToShow3: Double = 72
    
    /// the amount of hours of bg readings that the mini-chart should show (fourth range)
    static let miniChartHoursToShow4: Double = 168

}
