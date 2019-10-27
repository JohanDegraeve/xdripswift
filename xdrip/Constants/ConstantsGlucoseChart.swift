import Foundation

enum ConstantsGlucoseChart {
    
    /// default value for glucosechart width in hours
    static let defaultChartWidthInHours = 6.0;
    
    /// default value for timeformat for labels in chart, time axis
    ///
    /// H is hour 24 hour format, "h a" is hour 12 hour format  with a either am or pm
    static let defaultTimeAxisLabelFormat = "H"
    
    /// if unit is mgdl, we wil have a horizointal line each ... mgdl
    static let chartTableIncrementForMgDL = 50.0
    
    /// if unit is mmol, we wil have a horizointal line each ... mmol
    static let chartTableIncrementForMmol = 2.0
    
    /// usually 40.0 mgdl is the lowest value that cgm's give, putting it to 38 guarantees the points will always be visible
    ///
    /// only in mgdl because the label will not be shown, hence no bizar values to be shown when going to mgdl
    static let absoluteMinimumChartValueInMgdl = 38.0
    
    /// the minimum value that a cgm can show, it should be greater than absoluteMinimumChartValueInMgdl
    static let minimumCGMGlucoseValueInMgdl = 40.0
    
    /// default initial max mgdl value in chart, in mgdl - xdrip will try to maximize the use of the available height. If there's no glucose reading higher than this value, then the maximum in the graph will be this value
    ///
    /// it's default, because a user will be able to modify the value later in the settings  - in the code, the value will be
    static let defaultInitialMaxChartValueInMgdl = 200.0
    
    /// default initial max mmol value in chart, in mmol - xdrip will try to maximize the use of the available height. If there's no glucose reading higher than this value, then the maximum in the graph will be this value
    ///
    /// it's default, because a user will be able to modify the value later in the settings  - in the code, the value will be
    static let defaultInitialMaxChartValueInMmol = 11.0
    
    /// default increase  in maxium mgdl value in the chart, in mgdl - xdrip will try to maximize the use of the available height. If there's a glucose reading higher than the initial value, then the maximum will be increased with this value, until all readings fit in the chart
    ///
    /// it's default, because a user will be able to modify the value later in the settings
    static let defaultIncreaseMaxChartValueInMgdl = 100.0
    
    /// default increase  in maxium mmol value in the chart, in mmol - xdrip will try to maximize the use of the available height. If there's a glucose reading higher than the initial value, then the maximum will be increased with this value, until all readings fit in the chart
    ///
    /// it's default, because a user will be able to modify the value later in the settings
    static let defaultIncreaseMaxChartValueInMmol = 6.0

}
