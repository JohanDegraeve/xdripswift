//
//  ReportUserDefaults.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

extension UserDefaults {
    var reportPatientName: String {
        get {
            string(forKey: Key.reportPatientName.rawValue) ?? ""
        }
        set {
            set(newValue, forKey: Key.reportPatientName.rawValue)
        }
    }

    var reportPatientID: String {
        get {
            string(forKey: Key.reportPatientID.rawValue) ?? ""
        }
        set {
            set(newValue, forKey: Key.reportPatientID.rawValue)
        }
    }

    var reportPaperSize: GlucoseReportPaperSize {
        get {
            guard let rawValue = string(forKey: Key.reportPaperSize.rawValue),
                  let paperSize = GlucoseReportPaperSize(rawValue: rawValue)
            else {
                return .localeDefault
            }

            return paperSize
        }
        set {
            set(newValue.rawValue, forKey: Key.reportPaperSize.rawValue)
        }
    }

    var reportPeriod: GlucoseReportPeriod {
        get {
            let days = integer(forKey: Key.reportPeriod.rawValue)
            return GlucoseReportPeriod(rawValue: days) ?? .ninety
        }
        set {
            set(newValue.rawValue, forKey: Key.reportPeriod.rawValue)
        }
    }

    var reportLanguage: GlucoseReportLanguage {
        get {
            guard let rawValue = string(forKey: Key.reportLanguage.rawValue),
                  let language = GlucoseReportLanguage(rawValue: rawValue)
            else {
                return .english
            }

            return language
        }
        set {
            set(newValue.rawValue, forKey: Key.reportLanguage.rawValue)
        }
    }
}
