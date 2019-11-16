import Foundation
import SwiftCharts

extension ChartPoint {
    
    // if bgReading.calculatedValue == 0 then return  nil
    convenience init?(bgReading: BgReading, formatter: DateFormatter, unitIsMgDl: Bool) {
        
        if bgReading.calculatedValue > 0 {
            self.init(
                x: ChartAxisValueDate(date: bgReading.timeStamp, formatter: formatter),
                y: ChartAxisValueDouble(bgReading.calculatedValue.mgdlToMmol(mgdl: unitIsMgDl))
            )
        } else {
            return nil
        }

    }
}
