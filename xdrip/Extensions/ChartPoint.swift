import Foundation
import SwiftCharts

extension ChartPoint {
    
    convenience init(bgReading: BgReading, formatter: DateFormatter, unitIsMgDl: Bool) {
        
            self.init(
                x: ChartAxisValueDate(date: bgReading.timeStamp, formatter: formatter),
                y: ChartAxisValueDouble(bgReading.calculatedValue.mgDlToMmol(mgDl: unitIsMgDl))
            )

    }
    
    convenience init(calibration: Calibration, formatter: DateFormatter, unitIsMgDl: Bool) {
        
            self.init(
                x: ChartAxisValueDate(date: calibration.timeStamp, formatter: formatter),
                y: ChartAxisValueDouble(calibration.bg.mgDlToMmol(mgDl: unitIsMgDl))
            )

    }
    
    /* No longer used but can leave for any future use
    /// the chartpoints defined for bolus treatment entries are abolute-positioned in the chart and need to be scaled to fit the y-axis values of the glucose chart points (and therefore avoid needing a secondary axis).
    convenience init(treatmentEntry: TreatmentEntry, formatter: DateFormatter) {
        let scaledValue = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + treatmentEntry.value
        
        self.init(
            x: ChartAxisValueDate(date: treatmentEntry.date, formatter: formatter),
            y: ChartAxisValueDouble(scaledValue)
        )
    }
     */
    
    /// the bg check treatment value is always stored in mg/dl so needs to be converted/rounded as required to show correctly on the chart
    convenience init(bgCheck: TreatmentEntry, formatter: DateFormatter, unitIsMgDl: Bool) {
        
            self.init(
                x: ChartAxisValueDate(date: bgCheck.date, formatter: formatter),
                y: ChartAxisValueDouble(bgCheck.value.mgDlToMmol(mgDl: unitIsMgDl).bgValueRounded(mgDl: unitIsMgDl))
            )

    }
    
    /// the chartpoints defined for certain treatment entries (such as carbs) are positioned relative to other elements and need to be re-scaled to fit the y-axis values of the glucose chart points (and therefore avoid needing a secondary axis)
    convenience init(treatmentEntry: TreatmentEntry, formatter: DateFormatter, newYAxisValue: Double? = 0) {
        
        var yAxisValue: Double = treatmentEntry.value
        
        // if a new Y axis value exists, use this to set the chartpoint.y value. If not, just use  treatment.value
        if let value = newYAxisValue {
            yAxisValue = value
        }
        
        self.init(
            x: ChartAxisValueDate(date: treatmentEntry.date, formatter: formatter),
            y: ChartAxisValueDouble(yAxisValue.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl))
        )

    }
    
    /// the basal rate chart point from a treatment entry. Optional previous treatment entry (i.e. basal rate)
    /// If the previous basal rate is included, then it is used to create the ending point of the rate (i.e. current date but with previous value)
    /// if the previous basal rate is nil (i.e. not sent), then we'll assume we should just create a starting point of the rate (current date with current value)
    convenience init(basalRateTreatmentEntry: TreatmentEntry, previousBasalRateTreatmentEntry: TreatmentEntry?, basalRateScaler: Double, minimumChartValueinMgdl: Double, formatter: DateFormatter) {
            self.init(
                x: ChartAxisValueDate(date: basalRateTreatmentEntry.date, formatter: formatter),
                y: ChartAxisValueDouble(((previousBasalRateTreatmentEntry ?? basalRateTreatmentEntry).value.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) * basalRateScaler) + minimumChartValueinMgdl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl))
            )
    }
    
    /// the basal rate chart point from a treatment entry
    convenience init(basalRateTreatmentEntry: TreatmentEntry, date: Date, basalRateScaler: Double, minimumChartValueinMgdl: Double, formatter: DateFormatter) {
            self.init(
                x: ChartAxisValueDate(date: date, formatter: formatter),
                y: ChartAxisValueDouble((basalRateTreatmentEntry.value.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) * basalRateScaler) + minimumChartValueinMgdl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl))
            )
    }
    
    /// create a specific basal rate chart point at a specific date. This helps to clean up the start/end of the line and fill areas
    convenience init(basalRate: Double, date: Date, basalRateScaler: Double, minimumChartValueinMgdl: Double, formatter: DateFormatter) {
            self.init(
                x: ChartAxisValueDate(date: date, formatter: formatter),
                y: ChartAxisValueDouble((basalRate.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) * basalRateScaler) + minimumChartValueinMgdl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl))
            )
    }
    
}

extension SwiftCharts.ChartPoint: Swift.Comparable {
    
    public static func < (lhs: ChartPoint, rhs: ChartPoint) -> Bool {
        
        if let lhs = lhs.x as? ChartAxisValueDate, let rhs = rhs.x as? ChartAxisValueDate {
            
            return lhs.date < rhs.date
            
        }
        
        return false
        
    }
    
    public static func == (lhs: ChartPoint, rhs: ChartPoint) -> Bool {
        
        if let lhs = lhs.x as? ChartAxisValueDate, let rhs = rhs.x as? ChartAxisValueDate {
            
            return lhs.date == rhs.date
            
        }
        
        return false
        
    }

}
