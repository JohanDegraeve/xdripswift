import Foundation

extension UserDefaults {
    
    /// keys for settings and user defaults. For reading and writing settings, the keys should not be used, the specific functions kan be used.
    public enum KeysCharts: String {
        
        /// chart width in hours
        case chartWidthInHours = "chartWidthInHours"
        
    }
    
    /// chart width in hours
    @objc dynamic var chartWidthInHours:Double {
        get {

            var returnValue = double(forKey: KeysCharts.chartWidthInHours.rawValue)
            // if 0 set to defaultvalue
            if returnValue == 0.0 {
                returnValue = ConstantsGlucoseChart.defaultChartWidthInHours
            }

            return returnValue
        }
        set {

            set(newValue, forKey: KeysCharts.chartWidthInHours.rawValue)
        }
    }
    
}
