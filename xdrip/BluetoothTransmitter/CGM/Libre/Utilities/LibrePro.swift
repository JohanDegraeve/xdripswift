//
//  LibrePro.swift
//  DiaBox
//
//  Created by Yan Hu on 2020/6/28.
//  Copyright © 2020 DiaBox. All rights reserved.
//

import Foundation

// this class is for libre pro/h 
class LibrePro {
    
    static let max = 24
    private var startLen = 0
    
    private(set) var current: GlucoseData?
    
    /// sensorTime for libre pro/h
    private(set) var sensorTime: Int?
    
    private var f127d = [UInt8]()
    private var f126c: CLongLong = 0
    private var f125b: CLongLong = 0
    
    init(j: CLongLong, j2: CLongLong, bArr: [UInt8]) {
        f125b = j
        f126c = j2
        f127d = bArr
    }
    
    private func value(_ index: Int) -> Int {
        return Int(f127d[index])
    }

    private func mo221e(_ i: Int) -> Int {
        let a = value(i)
        let a2 = value(i + 1)
        let i2 = (a2 * 256) + a
        return i2
    }

    private func mo209a() -> Int {
        return histroy() - 5
    }

    private func mo212b(_ i: Int) -> Double {
        return mo208a(mo214b(i, 0), mo214b(i, 3))
    }

    private func history(_ index: Int) -> Int {
        return Int(historyData[index])
    }
    
    private func historyValue(_ i: Int) -> Double {
        let len = (i * 6) + startLen + 0
        let a = history(len)
        let a2 = history(len + 1)
        let v = (a2 * 256) + a
        return mo208a(v, v)
    }

    private func histroyTime(_ i: Int) -> CLongLong {
        let m0 = sensorStartTime()
        let m1 = histroy()
        let e = (m0 % 15) + ((m1 - i) * 15)
        let j = f126c
        return j - ((CLongLong(e) * 60) * 1000)
    }

    private func histroy() -> Int {
        let histroy = 256 * Int(f127d[79] & 0xFF) +  Int(f127d[78] & 0xFF)
        return histroy
    }

    private func trend() -> Int {
        let trend = 256 * Int(f127d[77] & 0xFF) + Int(f127d[76] & 0xFF)
        return trend
    }
    
    private func trendTime(_ i: Int) -> CLongLong {
        let d = ((trend() + 16) - i) % 16
        return f126c - ((CLongLong(d) * 60) * 1000)
    }


    private func sensorStartTime() -> Int {
        let sensorTime = 256 * Int(f127d[75] & 0xFF) + Int(f127d[74] & 0xFF)
        return sensorTime
    }

    private func historyIndex() -> Int {
        let h = histroy() - (Self.max * 8 / 6)
        return h
    }

    private func historyCount() -> Int {
        return (Self.max * 8 / 6)
    }
    private var historyData = [UInt8]()
    
    func proStart() -> Int? {
        var start: Int? = startByte()
        if start! <= 0 {
            start = nil
        }
        return start
    }
    
    func histroyData(historyData: [UInt8]) -> [GlucoseData] {
        self.historyData = historyData
        var history = [GlucoseData]()
        let factor: Double = 1
        
        for i in 0 ..< historyCount() {
            let b = historyValue(i) * factor
            if (b != -2.147483648E9) {
                let a = histroyTime(i + historyIndex())
                if (a != -2147483648) {
                    let glucoseData1 =  GlucoseData.init(timeStamp: Date(timeIntervalSince1970: TimeInterval(a / 1000)), glucoseLevelRaw: b)
                    if (glucoseData1.timeStamp < Date()) {
                        history.append(glucoseData1)
                    }
                }
            }
        }
        
        history = history.sorted(by: { (d1, d2) -> Bool in
            return d1.timeStamp > d2.timeStamp
        })
        return history
    }
    
    /// handle pro 344 data
    /// - Parameters:
    ///   - j: time
    ///   - j2: time
    ///   - bArr: 344 bytes
    /// - Returns: sensor time, current glucose, for history byte code, if not nil, should get history from bubble
    func mo211a() -> (sensorTime: Int, glucose: GlucoseData, start: Int?) {
        var trend = [GlucoseData]()
        let factor: Double = 1
        for i2 in 0 ..< mo222f() {
            let glucose = mo218d(i2)
            let d = glucose * factor
            let ts = trendTime(i2)
            let glucoseData1 =  GlucoseData.init(timeStamp: Date(timeIntervalSince1970: TimeInterval(ts / 1000)), glucoseLevelRaw: d)
            
            trend.append(glucoseData1)
        }
        
        let sensorTime = sensorStartTime()
        trend = trend.sorted(by: { (d1, d2) -> Bool in
            return d1.timeStamp > d2.timeStamp
        })
        
        current = trend.first
        self.sensorTime = sensorTime
        return (sensorTime, trend[0], proStart())
    }

    private func startByte() -> Int {
        let his = histroy() * 6 + 176 - Self.max * 8
        startLen = his % 8
        let start = (his - startLen) / 8
        return start
    }

    private func mathValue(_ trend: [GlucoseData]) -> Int {
        var all = 0
        var count = 0
        for gd in trend {
            if (count >= 5) {
                break
            }
            all = all + Int(gd.glucoseLevelRaw)
            count += 1
        }
        return all / count
    }

    private func mo219d() -> Int {
        let i = value(76) + (value(77) * 256)
        let i2 = ((i + 16) - 1) % 16
        if (i2 >= 0 && i2 < 16) {
            return i2
        }
        return 0
    }
    
    private func mo217c(_ i: Int) -> CLongLong {
        let d = ((mo219d() + 16) - i) % 16
        return f126c - ((CLongLong(d) * 60) * 1000)
    }

    private func mo214b(_ i: Int, _ i2: Int) -> Int {
        return mo221e((i * 6) + startLen + i2)
    }
    
    private func mo218d(_ i: Int) -> Double {
        return mo208a(mo216c(i, 0), mo216c(i, 3))
    }
    
    /* renamed from: c */
    private func mo216c(_ i: Int, _ i2: Int) -> Int {
        return mo221e((i * 6) + 80 + i2)
    }

    private func mo222f() -> Int {
        return 16
    }
    
    private func mo208a(_ i: Int, _ i2: Int) -> Double {
        let d = Double(i & 8191)
        let d2 = d / 8.5
        if (d2 <= 0.0) {
            return -2.147483648E9
        }
        return d2
    }
}
