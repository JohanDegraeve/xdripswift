//
//  ReportModels.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

enum GlucoseReportPeriod: Int, CaseIterable, Identifiable {
    case seven = 7
    case thirty = 30
    case sixty = 60
    case ninety = 90
    case oneEighty = 180
    case oneYear = 365

    var id: Int { rawValue }

    var title: String {
        return "\(rawValue)d"
    }

    var clinicalTitle: String {
        return "\(rawValue)-day report"
    }

    var optionTitle: String {
        return "\(rawValue) \(Texts_Common.days)"
    }

    func clinicalTitle(language: GlucoseReportLanguage) -> String {
        language.text(.periodReportFormat, rawValue)
    }

    var fileTitle: String {
        return "\(rawValue) day CGM Report"
    }
}

enum GlucoseReportLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case dutch = "nl"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english:
            return "English"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .dutch:
            return "Nederlands"
        case .german:
            return "Deutsch"
        case .italian:
            return "Italiano"
        case .portuguese:
            return "Português"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    func text(_ key: GlucoseReportText) -> String {
        switch self {
        case .english:
            return key.english
        case .spanish:
            return key.spanish
        case .french:
            return key.french
        case .dutch:
            return key.dutch
        case .german:
            return key.german
        case .italian:
            return key.italian
        case .portuguese:
            return key.portuguese
        }
    }

    func text(_ key: GlucoseReportText, _ arguments: CVarArg...) -> String {
        text(key, arguments: arguments)
    }

    func text(_ key: GlucoseReportText, arguments: [CVarArg]) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
}

enum GlucoseReportPaperSize: String, CaseIterable, Identifiable {
    case a4
    case usLetter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .a4:
            return "A4"
        case .usLetter:
            return "US Letter"
        }
    }

    var pageSize: CGSize {
        switch self {
        case .a4:
            return CGSize(width: 595.2, height: 841.8)
        case .usLetter:
            return CGSize(width: 612, height: 792)
        }
    }

    static var localeDefault: GlucoseReportPaperSize {
        Locale.current.region?.identifier == "US" ? .usLetter : .a4
    }
}

struct GlucoseReportConfiguration {
    var patientName: String
    var patientID: String
    var period: GlucoseReportPeriod
    var paperSize: GlucoseReportPaperSize
    var language: GlucoseReportLanguage

    func text(_ key: GlucoseReportText) -> String {
        language.text(key)
    }

    func text(_ key: GlucoseReportText, _ arguments: CVarArg...) -> String {
        language.text(key, arguments: arguments)
    }
}

struct GlucoseReport: Identifiable, Hashable {
    let id = UUID()
    let configuration: GlucoseReportConfiguration
    let generatedAt: Date
    let analytics: GlucoseReportAnalytics
    let pdfURL: URL
    let passwordToOpen: String?

    static func == (lhs: GlucoseReport, rhs: GlucoseReport) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct GlucoseReportAnalytics {
    let periodStart: Date
    let periodEnd: Date
    let firstReading: Date?
    let lastReading: Date?
    let sampleCount: Int
    let dataCapturePercentage: Double
    let readingsPerDay: Double
    let usesMgDl: Bool
    let averageMgDl: Double
    let standardDeviationMgDl: Double
    let coefficientOfVariation: Double
    let gmiPercentage: Double
    let rangeDistribution: GlucoseReportRangeDistribution
    let tightRangeDistribution: GlucoseReportRangeDistribution
    let agpPoints: [GlucoseReportAGPPoint]
    let dailySummaries: [GlucoseReportDailySummary]
    let trendPoints: [GlucoseReportTrendPoint]
    let deviceNames: [String]
    let sensorCount: Int
    let calibrationCount: Int
    let lowEventCount: Int
    let veryLowEventCount: Int
    let highEventCount: Int
    let veryHighEventCount: Int

    var hasData: Bool {
        sampleCount > 0
    }
}

struct GlucoseReportRangeDistribution {
    let veryLow: Double
    let low: Double
    let target: Double
    let high: Double
    let veryHigh: Double

    func timeInRangeBuckets(usesMgDl: Bool) -> [GlucoseReportRangeBucket] {
        [
            GlucoseReportRangeBucket(key: .low, detail: rangeLabel(upperMgDl: GlucoseReportClinicalConstants.timeInRangeLowMgDl, usesMgDl: usesMgDl), percentage: veryLow + low, color: GlucoseReportColors.low),
            GlucoseReportRangeBucket(key: .inRange, detail: rangeLabel(lowerMgDl: GlucoseReportClinicalConstants.timeInRangeLowMgDl, upperMgDl: GlucoseReportClinicalConstants.timeInRangeHighMgDl, usesMgDl: usesMgDl), percentage: target, color: GlucoseReportColors.target),
            GlucoseReportRangeBucket(key: .high, detail: rangeLabel(lowerMgDl: GlucoseReportClinicalConstants.timeInRangeHighMgDl, usesMgDl: usesMgDl), percentage: high + veryHigh, color: GlucoseReportColors.high)
        ]
    }

    static let timeInRangeSourceURL = "https://doi.org/10.2337/dci19-0028"
    static let timeInTightRangeSourceURL = "https://doi.org/10.2337/dci24-0058"

    static func tightRange(below: Double, target: Double, above: Double) -> GlucoseReportRangeDistribution {
        GlucoseReportRangeDistribution(
            veryLow: 0,
            low: below,
            target: target,
            high: above,
            veryHigh: 0
        )
    }

    func tightRangeBuckets(usesMgDl: Bool) -> [GlucoseReportRangeBucket] {
        [
            GlucoseReportRangeBucket(key: .low, detail: rangeLabel(upperMgDl: GlucoseReportClinicalConstants.timeInTightRangeLowMgDl, usesMgDl: usesMgDl), percentage: low, color: GlucoseReportColors.low),
            GlucoseReportRangeBucket(key: .tightRange, detail: rangeLabel(lowerMgDl: GlucoseReportClinicalConstants.timeInTightRangeLowMgDl, upperMgDl: GlucoseReportClinicalConstants.timeInTightRangeHighMgDl, usesMgDl: usesMgDl), percentage: target, color: GlucoseReportColors.target),
            GlucoseReportRangeBucket(key: .high, detail: rangeLabel(lowerMgDl: GlucoseReportClinicalConstants.timeInTightRangeHighMgDl, usesMgDl: usesMgDl), percentage: high, color: GlucoseReportColors.high)
        ]
    }

    private func rangeLabel(lowerMgDl: Double? = nil, upperMgDl: Double? = nil, usesMgDl: Bool) -> String {
        switch (lowerMgDl, upperMgDl) {
        case (.none, .some(let upperMgDl)):
            return "<\(formattedGlucoseLimit(upperMgDl, usesMgDl: usesMgDl))"
        case (.some(let lowerMgDl), .some(let upperMgDl)):
            return "\(formattedGlucoseLimit(lowerMgDl, usesMgDl: usesMgDl))-\(formattedGlucoseLimit(upperMgDl, usesMgDl: usesMgDl))"
        case (.some(let lowerMgDl), .none):
            return ">\(formattedGlucoseLimit(lowerMgDl, usesMgDl: usesMgDl))"
        case (.none, .none):
            return ""
        }
    }

    private func formattedGlucoseLimit(_ valueMgDl: Double, usesMgDl: Bool) -> String {
        if usesMgDl {
            return "\(Int(valueMgDl.rounded()))"
        }

        return (valueMgDl * ConstantsBloodGlucose.mgDlToMmoll)
            .round(toDecimalPlaces: 1)
            .stringWithoutTrailingZeroes
    }
}

struct GlucoseReportRangeBucket: Identifiable {
    let id = UUID()
    let key: GlucoseReportText
    let detail: String
    let percentage: Double
    let color: Color

    func title(language: GlucoseReportLanguage) -> String {
        language.text(key)
    }
}

struct GlucoseReportAGPPoint: Identifiable {
    let id = UUID()
    let minuteOfDay: Int
    let p5MgDl: Double
    let p25MgDl: Double
    let medianMgDl: Double
    let p75MgDl: Double
    let p95MgDl: Double
}

struct GlucoseReportDailySummary: Identifiable {
    let id = UUID()
    let date: Date
    let averageMgDl: Double
    let targetPercentage: Double
    let lowPercentage: Double
    let highPercentage: Double
    let sampleCount: Int
}

enum GlucoseReportTrendInterval: String {
    case weekly = "Weekly"
}

struct GlucoseReportTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let interval: GlucoseReportTrendInterval
    let averageMgDl: Double
    let coefficientOfVariation: Double
    let sampleCount: Int

    var gmiPercentage: Double {
        GlucoseReportClinicalMath.gmiPercentage(forAverageMgDl: averageMgDl)
    }
}

enum GlucoseReportClinicalConstants {
    // International Consensus on Time in Range: Diabetes Care 2019, 42(8), 1593-1603.
    // Source: https://doi.org/10.2337/dci19-0028
    static let veryLowMgDl = 54.0
    static let timeInRangeLowMgDl = 70.0
    static let timeInRangeHighMgDl = 180.0
    static let veryHighMgDl = 250.0

    // Time in Tight Range uses the emerging 70-140 mg/dL clinical definition.
    // Source: https://doi.org/10.2337/dci24-0058
    static let timeInTightRangeLowMgDl = 70.0
    static let timeInTightRangeHighMgDl = 140.0

    // The same consensus targets commonly use >=70% CGM data capture and >=70% TIR.
    static let minimumDataCapturePercentage = 70.0
    static let dailyTimeInRangeTargetPercentage = 70.0
    static let dailyLowTargetPercentage = 4.0
    static let dailyHighTargetPercentage = 25.0

    // CGM coefficient of variation <=36% is the usual threshold for acceptable glycaemic variability.
    // Source: https://doi.org/10.2337/dci19-0028
    static let coefficientOfVariationTargetPercentage = 36.0

    // Most supported CGM systems produce one reading every 5 minutes.
    static let expectedReadingsPerDay = 288
}

enum GlucoseReportClinicalMath {
    // GMI formula from Bergenstal et al., Diabetes Care 2018, 41(11), 2275-2280.
    // Source: https://doi.org/10.2337/dc18-1581
    static func gmiPercentage(forAverageMgDl averageMgDl: Double) -> Double {
        3.31 + 0.02392 * averageMgDl
    }
}

enum GlucoseReportAGPDisplayPoints {
    static func smoothedDisplayPoints(from points: [GlucoseReportAGPPoint]) -> [GlucoseReportAGPPoint] {
        var displayPoints = smoothed(points).sorted { $0.minuteOfDay < $1.minuteOfDay }
        guard !displayPoints.isEmpty else { return [] }

        if let first = displayPoints.first, first.minuteOfDay > 0 {
            displayPoints.insert(copy(first, minuteOfDay: 0), at: 0)
        }

        if let last = displayPoints.last, last.minuteOfDay < 1440 {
            let midnightPoint = displayPoints.first { $0.minuteOfDay == 0 } ?? last
            displayPoints.append(copy(midnightPoint, minuteOfDay: 1440))
        }

        return displayPoints
    }

    private static func smoothed(_ points: [GlucoseReportAGPPoint]) -> [GlucoseReportAGPPoint] {
        guard points.count >= 3 else { return points }

        return points.indices.map { index in
            let lowerIndex = max(points.startIndex, index - 1)
            let upperIndex = min(points.index(before: points.endIndex), index + 1)
            let window = Array(points[lowerIndex ... upperIndex])
            let ordered = [
                average(\.p5MgDl, in: window),
                average(\.p25MgDl, in: window),
                average(\.medianMgDl, in: window),
                average(\.p75MgDl, in: window),
                average(\.p95MgDl, in: window)
            ].sorted()

            return GlucoseReportAGPPoint(
                minuteOfDay: points[index].minuteOfDay,
                p5MgDl: ordered[0],
                p25MgDl: ordered[1],
                medianMgDl: ordered[2],
                p75MgDl: ordered[3],
                p95MgDl: ordered[4]
            )
        }
    }

    private static func average(_ keyPath: KeyPath<GlucoseReportAGPPoint, Double>, in points: [GlucoseReportAGPPoint]) -> Double {
        points.map { $0[keyPath: keyPath] }.reduce(0, +) / Double(points.count)
    }

    private static func copy(_ point: GlucoseReportAGPPoint, minuteOfDay: Int) -> GlucoseReportAGPPoint {
        GlucoseReportAGPPoint(
            minuteOfDay: minuteOfDay,
            p5MgDl: point.p5MgDl,
            p25MgDl: point.p25MgDl,
            medianMgDl: point.medianMgDl,
            p75MgDl: point.p75MgDl,
            p95MgDl: point.p95MgDl
        )
    }
}

enum GlucoseReportText {
    case continuousGlucoseMonitoringReport
    case generatedFormat
    case patient
    case patientID
    case dateRange
    case units
    case timeInRange
    case timeInTightRange
    case low
    case inRange
    case tightRange
    case high
    case timeInRangeSource
    case timeInTightRangeSource
    case ambulatoryGlucoseProfile
    case insufficientAGPData
    case averageGlucose
    case consensusEstimate
    case targetLessThanOrEqual
    case targetGreaterThanOrEqual
    case targetLessThan
    case readings
    case timeBelowRange
    case timeAboveRange
    case dailyPatternSummary
    case bestTIR
    case lowestAverage
    case highestAverage
    case estimatedA1cAndVariabilityTrend
    case estimatedA1cGMI
    case lowerIsGenerallyBetter
    case cv
    case weekly
    case insufficientData
    case gmiFootnote
    case cgmSystemAndReportQuality
    case cgmSource
    case storedCGMReadings
    case currentSensor
    case sensorsInPeriod
    case calibrations
    case firstReading
    case lastReading
    case dataCapture
    case reportInterpretationNote
    case footerGeneratedFormat
    case pageFormat
    case periodReportFormat

    var english: String {
        switch self {
        case .continuousGlucoseMonitoringReport: return "Continuous Glucose Monitoring Report"
        case .generatedFormat: return "Generated %@"
        case .patient: return "Patient"
        case .patientID: return "Patient ID"
        case .dateRange: return "Date Range"
        case .units: return "Units"
        case .timeInRange: return "Time in Range"
        case .timeInTightRange: return "Time in Tight Range"
        case .low: return "Low"
        case .inRange: return "In Range"
        case .tightRange: return "Tight Range"
        case .high: return "High"
        case .timeInRangeSource: return "Limits: International Consensus on Time in Range"
        case .timeInTightRangeSource: return "Limits: Time in tight range clinical definition"
        case .ambulatoryGlucoseProfile: return "Ambulatory Glucose Profile"
        case .insufficientAGPData: return "Insufficient data for AGP percentile chart"
        case .averageGlucose: return "Average Glucose"
        case .consensusEstimate: return "consensus estimate"
        case .targetLessThanOrEqual: return "target <=%@"
        case .targetGreaterThanOrEqual: return "target >=%@"
        case .targetLessThan: return "target <%@"
        case .readings: return "Readings"
        case .timeBelowRange: return "Time Below Range"
        case .timeAboveRange: return "Time Above Range"
        case .dailyPatternSummary: return "Daily Pattern Summary"
        case .bestTIR: return "Best TIR"
        case .lowestAverage: return "Lowest Avg"
        case .highestAverage: return "Highest Avg"
        case .estimatedA1cAndVariabilityTrend: return "Estimated A1c and Variability Trend"
        case .estimatedA1cGMI: return "Estimated A1c / GMI"
        case .lowerIsGenerallyBetter: return "Lower is generally better"
        case .cv: return "CV"
        case .weekly: return "Weekly"
        case .insufficientData: return "Insufficient data"
        case .gmiFootnote: return "GMI is CGM-derived and should be interpreted as an estimate, not a laboratory HbA1c result."
        case .cgmSystemAndReportQuality: return "CGM System and Report Quality"
        case .cgmSource: return "CGM Source"
        case .storedCGMReadings: return "Stored CGM readings"
        case .currentSensor: return "Current Sensor"
        case .sensorsInPeriod: return "Sensors in Period"
        case .calibrations: return "Calibrations"
        case .firstReading: return "First Reading"
        case .lastReading: return "Last Reading"
        case .dataCapture: return "Data Capture"
        case .reportInterpretationNote: return "This report summarizes stored CGM readings for clinical review. It is not a real-time treatment display and should be interpreted with the user's care team."
        case .footerGeneratedFormat: return "Generated by %@ (%@) from locally stored CGM data."
        case .pageFormat: return "Page %d of %d"
        case .periodReportFormat: return "%d-day report"
        }
    }

    var spanish: String {
        switch self {
        case .continuousGlucoseMonitoringReport: return "Informe de Monitorización Continua de Glucosa"
        case .generatedFormat: return "Generado %@"
        case .patient: return "Paciente"
        case .patientID: return "ID del paciente"
        case .dateRange: return "Periodo"
        case .units: return "Unidades"
        case .timeInRange: return "Tiempo en Rango"
        case .timeInTightRange: return "Tiempo en Rango Estrecho"
        case .low: return "Bajo"
        case .inRange: return "En Rango"
        case .tightRange: return "Rango Estrecho"
        case .high: return "Alto"
        case .timeInRangeSource: return "Límites: Consenso internacional sobre tiempo en rango"
        case .timeInTightRangeSource: return "Límites: definición clínica de tiempo en rango estrecho"
        case .ambulatoryGlucoseProfile: return "Perfil Ambulatorio de Glucosa"
        case .insufficientAGPData: return "Datos insuficientes para el gráfico percentil AGP"
        case .averageGlucose: return "Glucosa Media"
        case .consensusEstimate: return "estimación de consenso"
        case .targetLessThanOrEqual: return "objetivo <=%@"
        case .targetGreaterThanOrEqual: return "objetivo >=%@"
        case .targetLessThan: return "objetivo <%@"
        case .readings: return "Lecturas"
        case .timeBelowRange: return "Tiempo Bajo Rango"
        case .timeAboveRange: return "Tiempo Sobre Rango"
        case .dailyPatternSummary: return "Resumen del Patrón Diario"
        case .bestTIR: return "Mejor TIR"
        case .lowestAverage: return "Media Mínima"
        case .highestAverage: return "Media Máxima"
        case .estimatedA1cAndVariabilityTrend: return "Tendencia de A1c Estimada y Variabilidad"
        case .estimatedA1cGMI: return "A1c Estimada / GMI"
        case .lowerIsGenerallyBetter: return "Más bajo suele ser mejor"
        case .cv: return "CV"
        case .weekly: return "Semanal"
        case .insufficientData: return "Datos insuficientes"
        case .gmiFootnote: return "El GMI se deriva de la MCG y debe interpretarse como una estimación, no como un resultado de HbA1c de laboratorio."
        case .cgmSystemAndReportQuality: return "Sistema MCG y Calidad del Informe"
        case .cgmSource: return "Fuente MCG"
        case .storedCGMReadings: return "Lecturas MCG almacenadas"
        case .currentSensor: return "Sensor Actual"
        case .sensorsInPeriod: return "Sensores en el Periodo"
        case .calibrations: return "Calibraciones"
        case .firstReading: return "Primera Lectura"
        case .lastReading: return "Última Lectura"
        case .dataCapture: return "Captura de Datos"
        case .reportInterpretationNote: return "Este informe resume lecturas MCG almacenadas para revisión clínica. No es una pantalla de tratamiento en tiempo real y debe interpretarse con el equipo médico del usuario."
        case .footerGeneratedFormat: return "Generado por %@ (%@) a partir de datos MCG almacenados localmente."
        case .pageFormat: return "Página %d de %d"
        case .periodReportFormat: return "Informe de %d días"
        }
    }

    var french: String {
        switch self {
        case .continuousGlucoseMonitoringReport: return "Rapport de Surveillance Continue du Glucose"
        case .generatedFormat: return "Généré %@"
        case .patient: return "Patient"
        case .patientID: return "ID du patient"
        case .dateRange: return "Période"
        case .units: return "Unités"
        case .timeInRange: return "Temps dans la Cible"
        case .timeInTightRange: return "Temps dans la Cible Stricte"
        case .low: return "Bas"
        case .inRange: return "Dans la Cible"
        case .tightRange: return "Cible Stricte"
        case .high: return "Élevé"
        case .timeInRangeSource: return "Limites : consensus international sur le temps dans la cible"
        case .timeInTightRangeSource: return "Limites : définition clinique du temps dans la cible stricte"
        case .ambulatoryGlucoseProfile: return "Profil Ambulatoire du Glucose"
        case .insufficientAGPData: return "Données insuffisantes pour le graphique percentile AGP"
        case .averageGlucose: return "Glucose Moyen"
        case .consensusEstimate: return "estimation consensuelle"
        case .targetLessThanOrEqual: return "objectif <=%@"
        case .targetGreaterThanOrEqual: return "objectif >=%@"
        case .targetLessThan: return "objectif <%@"
        case .readings: return "Lectures"
        case .timeBelowRange: return "Temps sous la Cible"
        case .timeAboveRange: return "Temps au-dessus de la Cible"
        case .dailyPatternSummary: return "Résumé du Profil Quotidien"
        case .bestTIR: return "Meilleur TIR"
        case .lowestAverage: return "Moy. la plus basse"
        case .highestAverage: return "Moy. la plus haute"
        case .estimatedA1cAndVariabilityTrend: return "Tendance A1c Estimée et Variabilité"
        case .estimatedA1cGMI: return "A1c Estimée / GMI"
        case .lowerIsGenerallyBetter: return "Plus bas est généralement meilleur"
        case .cv: return "CV"
        case .weekly: return "Hebdomadaire"
        case .insufficientData: return "Données insuffisantes"
        case .gmiFootnote: return "Le GMI est dérivé de la MCG et doit être interprété comme une estimation, pas comme un résultat d'HbA1c de laboratoire."
        case .cgmSystemAndReportQuality: return "Système MCG et Qualité du Rapport"
        case .cgmSource: return "Source MCG"
        case .storedCGMReadings: return "Lectures MCG stockées"
        case .currentSensor: return "Capteur Actuel"
        case .sensorsInPeriod: return "Capteurs sur la Période"
        case .calibrations: return "Étalonnages"
        case .firstReading: return "Première Lecture"
        case .lastReading: return "Dernière Lecture"
        case .dataCapture: return "Capture des Données"
        case .reportInterpretationNote: return "Ce rapport résume les lectures MCG stockées pour examen clinique. Il ne s'agit pas d'un affichage de traitement en temps réel et il doit être interprété avec l'équipe soignante de l'utilisateur."
        case .footerGeneratedFormat: return "Généré par %@ (%@) à partir de données MCG stockées localement."
        case .pageFormat: return "Page %d sur %d"
        case .periodReportFormat: return "Rapport de %d jours"
        }
    }

    var dutch: String {
        switch self {
        case .continuousGlucoseMonitoringReport: return "Rapport Continue Glucosemonitoring"
        case .generatedFormat: return "Gegenereerd %@"
        case .patient: return "Patiënt"
        case .patientID: return "Patiënt-ID"
        case .dateRange: return "Periode"
        case .units: return "Eenheden"
        case .timeInRange: return "Tijd binnen Bereik"
        case .timeInTightRange: return "Tijd binnen Strak Bereik"
        case .low: return "Laag"
        case .inRange: return "Binnen Bereik"
        case .tightRange: return "Strak Bereik"
        case .high: return "Hoog"
        case .timeInRangeSource: return "Limieten: internationale consensus over tijd binnen bereik"
        case .timeInTightRangeSource: return "Limieten: klinische definitie van tijd binnen strak bereik"
        case .ambulatoryGlucoseProfile: return "Ambulant Glucoseprofiel"
        case .insufficientAGPData: return "Onvoldoende gegevens voor AGP-percentielgrafiek"
        case .averageGlucose: return "Gemiddelde Glucose"
        case .consensusEstimate: return "consensusschatting"
        case .targetLessThanOrEqual: return "doel <=%@"
        case .targetGreaterThanOrEqual: return "doel >=%@"
        case .targetLessThan: return "doel <%@"
        case .readings: return "Metingen"
        case .timeBelowRange: return "Tijd onder Bereik"
        case .timeAboveRange: return "Tijd boven Bereik"
        case .dailyPatternSummary: return "Samenvatting Dagpatroon"
        case .bestTIR: return "Beste TIR"
        case .lowestAverage: return "Laagste Gem."
        case .highestAverage: return "Hoogste Gem."
        case .estimatedA1cAndVariabilityTrend: return "Trend Geschatte A1c en Variabiliteit"
        case .estimatedA1cGMI: return "Geschatte A1c / GMI"
        case .lowerIsGenerallyBetter: return "Lager is meestal beter"
        case .cv: return "CV"
        case .weekly: return "Wekelijks"
        case .insufficientData: return "Onvoldoende gegevens"
        case .gmiFootnote: return "GMI is afgeleid van CGM en moet worden geïnterpreteerd als een schatting, niet als een laboratorium-HbA1c-resultaat."
        case .cgmSystemAndReportQuality: return "CGM-systeem en Rapportkwaliteit"
        case .cgmSource: return "CGM-bron"
        case .storedCGMReadings: return "Opgeslagen CGM-metingen"
        case .currentSensor: return "Huidige Sensor"
        case .sensorsInPeriod: return "Sensoren in Periode"
        case .calibrations: return "Kalibraties"
        case .firstReading: return "Eerste Meting"
        case .lastReading: return "Laatste Meting"
        case .dataCapture: return "Gegevensdekking"
        case .reportInterpretationNote: return "Dit rapport vat opgeslagen CGM-metingen samen voor klinische beoordeling. Het is geen realtime behandelweergave en moet samen met het zorgteam van de gebruiker worden geïnterpreteerd."
        case .footerGeneratedFormat: return "Gegenereerd door %@ (%@) op basis van lokaal opgeslagen CGM-gegevens."
        case .pageFormat: return "Pagina %d van %d"
        case .periodReportFormat: return "%d-daags rapport"
        }
    }

    var german: String {
        switch self {
        case .continuousGlucoseMonitoringReport: return "Bericht zur Kontinuierlichen Glukosemessung"
        case .generatedFormat: return "Erstellt %@"
        case .patient: return "Patient"
        case .patientID: return "Patienten-ID"
        case .dateRange: return "Zeitraum"
        case .units: return "Einheiten"
        case .timeInRange: return "Zeit im Zielbereich"
        case .timeInTightRange: return "Zeit im Engen Zielbereich"
        case .low: return "Niedrig"
        case .inRange: return "Im Zielbereich"
        case .tightRange: return "Enger Zielbereich"
        case .high: return "Hoch"
        case .timeInRangeSource: return "Grenzwerte: internationaler Konsens zur Zeit im Zielbereich"
        case .timeInTightRangeSource: return "Grenzwerte: klinische Definition der Zeit im engen Zielbereich"
        case .ambulatoryGlucoseProfile: return "Ambulantes Glukoseprofil"
        case .insufficientAGPData: return "Nicht genügend Daten für das AGP-Perzentildiagramm"
        case .averageGlucose: return "Durchschnittsglukose"
        case .consensusEstimate: return "Konsensschätzung"
        case .targetLessThanOrEqual: return "Ziel <=%@"
        case .targetGreaterThanOrEqual: return "Ziel >=%@"
        case .targetLessThan: return "Ziel <%@"
        case .readings: return "Messwerte"
        case .timeBelowRange: return "Zeit unter Zielbereich"
        case .timeAboveRange: return "Zeit über Zielbereich"
        case .dailyPatternSummary: return "Zusammenfassung Tagesmuster"
        case .bestTIR: return "Beste TIR"
        case .lowestAverage: return "Niedrigster Ø"
        case .highestAverage: return "Höchster Ø"
        case .estimatedA1cAndVariabilityTrend: return "Trend Geschätzte A1c und Variabilität"
        case .estimatedA1cGMI: return "Geschätzte A1c / GMI"
        case .lowerIsGenerallyBetter: return "Niedriger ist im Allgemeinen besser"
        case .cv: return "CV"
        case .weekly: return "Wöchentlich"
        case .insufficientData: return "Nicht genügend Daten"
        case .gmiFootnote: return "GMI wird aus CGM-Daten abgeleitet und sollte als Schätzung interpretiert werden, nicht als Labor-HbA1c-Ergebnis."
        case .cgmSystemAndReportQuality: return "CGM-System und Berichtsqualität"
        case .cgmSource: return "CGM-Quelle"
        case .storedCGMReadings: return "Gespeicherte CGM-Messwerte"
        case .currentSensor: return "Aktueller Sensor"
        case .sensorsInPeriod: return "Sensoren im Zeitraum"
        case .calibrations: return "Kalibrierungen"
        case .firstReading: return "Erster Messwert"
        case .lastReading: return "Letzter Messwert"
        case .dataCapture: return "Datenerfassung"
        case .reportInterpretationNote: return "Dieser Bericht fasst gespeicherte CGM-Messwerte zur klinischen Beurteilung zusammen. Er ist keine Echtzeit-Behandlungsanzeige und sollte mit dem Behandlungsteam des Benutzers interpretiert werden."
        case .footerGeneratedFormat: return "Erstellt von %@ (%@) aus lokal gespeicherten CGM-Daten."
        case .pageFormat: return "Seite %d von %d"
        case .periodReportFormat: return "%d-Tage-Bericht"
        }
    }

    var italian: String {
        switch self {
        case .continuousGlucoseMonitoringReport: return "Report di Monitoraggio Continuo del Glucosio"
        case .generatedFormat: return "Generato %@"
        case .patient: return "Paziente"
        case .patientID: return "ID paziente"
        case .dateRange: return "Periodo"
        case .units: return "Unità"
        case .timeInRange: return "Tempo nell'Intervallo"
        case .timeInTightRange: return "Tempo nell'Intervallo Stretto"
        case .low: return "Basso"
        case .inRange: return "Nell'Intervallo"
        case .tightRange: return "Intervallo Stretto"
        case .high: return "Alto"
        case .timeInRangeSource: return "Limiti: consenso internazionale sul tempo nell'intervallo"
        case .timeInTightRangeSource: return "Limiti: definizione clinica del tempo nell'intervallo stretto"
        case .ambulatoryGlucoseProfile: return "Profilo Ambulatoriale del Glucosio"
        case .insufficientAGPData: return "Dati insufficienti per il grafico percentile AGP"
        case .averageGlucose: return "Glucosio Medio"
        case .consensusEstimate: return "stima di consenso"
        case .targetLessThanOrEqual: return "obiettivo <=%@"
        case .targetGreaterThanOrEqual: return "obiettivo >=%@"
        case .targetLessThan: return "obiettivo <%@"
        case .readings: return "Letture"
        case .timeBelowRange: return "Tempo sotto Intervallo"
        case .timeAboveRange: return "Tempo sopra Intervallo"
        case .dailyPatternSummary: return "Riepilogo Andamento Giornaliero"
        case .bestTIR: return "Miglior TIR"
        case .lowestAverage: return "Media Minima"
        case .highestAverage: return "Media Massima"
        case .estimatedA1cAndVariabilityTrend: return "Tendenza A1c Stimata e Variabilità"
        case .estimatedA1cGMI: return "A1c Stimata / GMI"
        case .lowerIsGenerallyBetter: return "Più basso è generalmente meglio"
        case .cv: return "CV"
        case .weekly: return "Settimanale"
        case .insufficientData: return "Dati insufficienti"
        case .gmiFootnote: return "Il GMI deriva dal CGM e deve essere interpretato come una stima, non come un risultato HbA1c di laboratorio."
        case .cgmSystemAndReportQuality: return "Sistema CGM e Qualità del Report"
        case .cgmSource: return "Fonte CGM"
        case .storedCGMReadings: return "Letture CGM memorizzate"
        case .currentSensor: return "Sensore Attuale"
        case .sensorsInPeriod: return "Sensori nel Periodo"
        case .calibrations: return "Calibrazioni"
        case .firstReading: return "Prima Lettura"
        case .lastReading: return "Ultima Lettura"
        case .dataCapture: return "Acquisizione Dati"
        case .reportInterpretationNote: return "Questo report riassume le letture CGM memorizzate per revisione clinica. Non è una visualizzazione terapeutica in tempo reale e deve essere interpretato con il team sanitario dell'utente."
        case .footerGeneratedFormat: return "Generato da %@ (%@) da dati CGM memorizzati localmente."
        case .pageFormat: return "Pagina %d di %d"
        case .periodReportFormat: return "Report di %d giorni"
        }
    }

    var portuguese: String {
        switch self {
        case .continuousGlucoseMonitoringReport: return "Relatório de Monitorização Contínua da Glicose"
        case .generatedFormat: return "Gerado %@"
        case .patient: return "Paciente"
        case .patientID: return "ID do paciente"
        case .dateRange: return "Período"
        case .units: return "Unidades"
        case .timeInRange: return "Tempo no Intervalo"
        case .timeInTightRange: return "Tempo no Intervalo Estrito"
        case .low: return "Baixo"
        case .inRange: return "No Intervalo"
        case .tightRange: return "Intervalo Estrito"
        case .high: return "Alto"
        case .timeInRangeSource: return "Limites: consenso internacional sobre tempo no intervalo"
        case .timeInTightRangeSource: return "Limites: definição clínica de tempo no intervalo estrito"
        case .ambulatoryGlucoseProfile: return "Perfil Ambulatorial da Glicose"
        case .insufficientAGPData: return "Dados insuficientes para o gráfico percentil AGP"
        case .averageGlucose: return "Glicose Média"
        case .consensusEstimate: return "estimativa de consenso"
        case .targetLessThanOrEqual: return "alvo <=%@"
        case .targetGreaterThanOrEqual: return "alvo >=%@"
        case .targetLessThan: return "alvo <%@"
        case .readings: return "Leituras"
        case .timeBelowRange: return "Tempo Abaixo do Intervalo"
        case .timeAboveRange: return "Tempo Acima do Intervalo"
        case .dailyPatternSummary: return "Resumo do Padrão Diário"
        case .bestTIR: return "Melhor TIR"
        case .lowestAverage: return "Média Mínima"
        case .highestAverage: return "Média Máxima"
        case .estimatedA1cAndVariabilityTrend: return "Tendência de A1c Estimada e Variabilidade"
        case .estimatedA1cGMI: return "A1c Estimada / GMI"
        case .lowerIsGenerallyBetter: return "Mais baixo é geralmente melhor"
        case .cv: return "CV"
        case .weekly: return "Semanal"
        case .insufficientData: return "Dados insuficientes"
        case .gmiFootnote: return "O GMI é derivado da MCG e deve ser interpretado como uma estimativa, não como um resultado laboratorial de HbA1c."
        case .cgmSystemAndReportQuality: return "Sistema MCG e Qualidade do Relatório"
        case .cgmSource: return "Fonte MCG"
        case .storedCGMReadings: return "Leituras MCG armazenadas"
        case .currentSensor: return "Sensor Atual"
        case .sensorsInPeriod: return "Sensores no Período"
        case .calibrations: return "Calibrações"
        case .firstReading: return "Primeira Leitura"
        case .lastReading: return "Última Leitura"
        case .dataCapture: return "Captura de Dados"
        case .reportInterpretationNote: return "Este relatório resume leituras MCG armazenadas para revisão clínica. Não é uma visualização de tratamento em tempo real e deve ser interpretado com a equipa clínica do utilizador."
        case .footerGeneratedFormat: return "Gerado por %@ (%@) a partir de dados MCG armazenados localmente."
        case .pageFormat: return "Página %d de %d"
        case .periodReportFormat: return "Relatório de %d dias"
        }
    }
}

enum GlucoseReportColors {
    static let pageBackground = Color.white
    static let primaryText = Color(red: 0.09, green: 0.12, blue: 0.16)
    static let secondaryText = Color(red: 0.35, green: 0.39, blue: 0.44)
    static let tertiaryText = Color(red: 0.55, green: 0.59, blue: 0.64)
    static let rule = Color(red: 0.84, green: 0.87, blue: 0.90)
    static let panel = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let patientPanel = Color(red: 0.90, green: 0.95, blue: 1.00)
    static let clinicalBlue = Color(red: 0.05, green: 0.27, blue: 0.48)
    static let veryLow = ConstantsAppColors.urgent
    static let low = ConstantsAppColors.statisticsLow
    static let target = ConstantsAppColors.statisticsInRange
    static let high = ConstantsAppColors.statisticsHigh
    static let veryHigh = ConstantsAppColors.urgent
    static let agpOuterBand = Color(red: 0.72, green: 0.76, blue: 0.82).opacity(0.46)
    static let agpInnerBand = Color(red: 0.25, green: 0.50, blue: 0.74).opacity(0.42)
    static let agpOuterLine = Color(red: 0.50, green: 0.57, blue: 0.66)
    static let agpInnerLine = Color(red: 0.20, green: 0.41, blue: 0.62)
}
