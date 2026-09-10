import Foundation

/// Конфигурационные константы для Aidex/Linx/Lumiflex CGM.
enum ConstantsAidex {
    /// Минимальное время прогрева сенсора (минут).
    /// AidexSensor использует 7-минутный warmup после активации.
    static let warmupMinutes: Double = 7
}