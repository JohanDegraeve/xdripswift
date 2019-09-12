import Foundation

/// extends RawGlucoseData and adds property unsmoothedGlucose, because this is only used for Libre
class LibreRawGlucoseData: GlucoseData {
    
    var unsmoothedGlucose: Double

    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double, unsmoothedGlucose: Double = 0.0) {
        self.unsmoothedGlucose = unsmoothedGlucose

        super.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelFiltered)
    }
    
    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date, unsmoothedGlucose: Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: 0.0, glucoseLevelFiltered: 0.0, unsmoothedGlucose: unsmoothedGlucose)
    }

}

class LibreRawGlucoseOOPData: NSObject, Codable {
    var alarm : String?
    var esaMinutesToWait : Int?
    var historicGlucose : [HistoricGlucose]?
    var isActionable : Bool?
    var lsaDetected : Bool?
    var realTimeGlucose : HistoricGlucose?
    var trendArrow : String?
    
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
        var current: LibreRawGlucoseData?
        if let g = realTimeGlucose, g.dataQuality == 0 {
            current = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
        }
        var array = [LibreRawGlucoseData]()
        let gap: TimeInterval = 60 * 15
        var date = date
        if var history = historicGlucose {
            if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
                history = history.reversed()
            }
            for g in history {
                date = date.addingTimeInterval(-gap)
                if g.dataQuality != 0 { continue }
                let glucose = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
                array.append(glucose)
            }
        }
        
        
        return (current ,array)
    }
}

class HistoricGlucose: NSObject, Codable {
    let dataQuality : Int?
    let id: Int?
    let value : Double?
}
