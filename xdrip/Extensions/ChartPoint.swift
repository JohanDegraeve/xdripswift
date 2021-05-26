import Foundation
import SwiftCharts

extension ChartPoint {
    
    convenience init(bgReading: BgReading, formatter: DateFormatter, unitIsMgDl: Bool) {
        
            self.init(
                x: ChartAxisValueDate(date: bgReading.timeStamp, formatter: formatter),
                y: ChartAxisValueDouble(bgReading.calculatedValue.mgdlToMmol(mgdl: unitIsMgDl))
            )

    }
    
    convenience init(calibration: Calibration, formatter: DateFormatter, unitIsMgDl: Bool) {
        
            self.init(
                x: ChartAxisValueDate(date: calibration.timeStamp, formatter: formatter),
                y: ChartAxisValueDouble(calibration.bg.mgdlToMmol(mgdl: unitIsMgDl))
            )

    }
}

extension ChartPoint: Comparable {
    
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
