import Foundation

/// Represents different insulin types with their absorption profiles
public enum InsulinType: String, CaseIterable {
    case rapidActing = "Rapid-Acting"
    case shortActing = "Short-Acting"
    case humalogNovolog = "Humalog/Novolog"
    case fiasp = "Fiasp"
    case apidra = "Apidra"
    case custom = "Custom"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .rapidActing: return "Rapid-Acting (Generic)"
        case .shortActing: return "Short-Acting (Generic)"
        case .humalogNovolog: return "Humalog/Novolog/Novorapid"
        case .fiasp: return "Fiasp"
        case .apidra: return "Apidra"
        case .custom: return "Custom Profile"
        }
    }
    
    /// Default insulin profile parameters
    public var profile: InsulinProfile {
        switch self {
        case .rapidActing:
            // Generic rapid-acting profile
            return InsulinProfile(
                insulinType: self,
                onsetMinutes: 15,
                peakMinutes: 75,
                durationMinutes: 180 // 3 hours
            )
            
        case .shortActing:
            // Generic short-acting profile
            return InsulinProfile(
                insulinType: self,
                onsetMinutes: 30,
                peakMinutes: 120,
                durationMinutes: 300 // 5 hours
            )
            
        case .humalogNovolog:
            // Based on xDrip Android data
            return InsulinProfile(
                insulinType: self,
                onsetMinutes: 10,
                peakMinutes: 75,
                durationMinutes: 180 // 3 hours
            )
            
        case .fiasp:
            // Ultra-rapid acting
            return InsulinProfile(
                insulinType: self,
                onsetMinutes: 2,
                peakMinutes: 45,
                durationMinutes: 300 // 5 hours but with faster action
            )
            
        case .apidra:
            return InsulinProfile(
                insulinType: self,
                onsetMinutes: 10,
                peakMinutes: 60,
                durationMinutes: 300 // 5 hours
            )
            
        case .custom:
            // Default to rapid-acting, user can customize
            return InsulinProfile(
                insulinType: self,
                onsetMinutes: 15,
                peakMinutes: 75,
                durationMinutes: 180
            )
        }
    }
}

/// Insulin absorption profile parameters
public struct InsulinProfile {
    public let insulinType: InsulinType
    public let onsetMinutes: Double
    public let peakMinutes: Double
    public let durationMinutes: Double
    
    /// Calculate insulin activity at a given time using Linear Trapezoid model
    /// - Parameter minutesAfterBolus: Time in minutes since insulin was administered
    /// - Returns: Relative activity level (0.0 to 1.0)
    public func activity(at minutesAfterBolus: Double) -> Double {
        // No activity before onset or after duration
        guard minutesAfterBolus >= onsetMinutes && minutesAfterBolus <= durationMinutes else {
            return 0.0
        }
        
        // Linear Trapezoid model (similar to Android xDrip)
        if minutesAfterBolus <= peakMinutes {
            // Rising phase: linear from onset to peak
            let progress = (minutesAfterBolus - onsetMinutes) / (peakMinutes - onsetMinutes)
            return progress
        } else {
            // Falling phase: linear from peak to end
            let progress = (durationMinutes - minutesAfterBolus) / (durationMinutes - peakMinutes)
            return progress
        }
    }
    
    /// Calculate the fraction of insulin absorbed at a given time
    /// - Parameter minutesAfterBolus: Time in minutes since insulin was administered
    /// - Returns: Fraction absorbed (0.0 to 1.0)
    public func absorption(at minutesAfterBolus: Double) -> Double {
        guard minutesAfterBolus > 0 else { return 0.0 }
        guard minutesAfterBolus < durationMinutes else { return 1.0 }
        
        // Integrate the activity curve from 0 to minutesAfterBolus
        // Using trapezoidal integration with 5-minute steps
        let stepSize: Double = 5.0
        var totalAbsorbed: Double = 0.0
        var totalArea: Double = 0.0
        
        // Calculate total area under the curve (for normalization)
        var t: Double = 0
        while t <= durationMinutes {
            totalArea += activity(at: t) * stepSize
            t += stepSize
        }
        
        // Calculate absorbed up to minutesAfterBolus
        t = 0
        while t <= minutesAfterBolus && t <= durationMinutes {
            totalAbsorbed += activity(at: t) * stepSize
            t += stepSize
        }
        
        return totalAbsorbed / totalArea
    }
    
    /// Calculate remaining active insulin (IOB)
    /// - Parameter minutesAfterBolus: Time in minutes since insulin was administered
    /// - Returns: Fraction remaining (0.0 to 1.0)
    public func iobFraction(at minutesAfterBolus: Double) -> Double {
        return 1.0 - absorption(at: minutesAfterBolus)
    }
}

/// Default values for insulin calculations
public struct InsulinDefaults {
    /// Default insulin sensitivity factor (ISF) - how much 1 unit drops glucose
    /// 54 mg/dL per unit (or 3.0 mmol/L per unit)
    public static let insulinSensitivityMgDl: Double = 54.0
    public static let insulinSensitivityMmol: Double = 3.0
    
    /// Default carb ratio (ICR) - grams of carbs per 1 unit of insulin
    public static let carbRatio: Double = 10.0
    
    /// Default duration of insulin action (DIA) in hours
    public static let insulinActionDuration: Double = 3.0
    
    /// Default carb absorption rate in grams per hour
    public static let carbAbsorptionRate: Double = 35.0
    
    /// Default carb absorption delay in minutes
    public static let carbAbsorptionDelay: Double = 15.0
}