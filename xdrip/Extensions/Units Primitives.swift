//
//  Units Primitives.swift
//  xdrip
//
//  Created by Todd Dalton on 08/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation



/*
 Effectively we're creating new numeric literals. A good explanation here:
 
 https://fabiancanas.com/blog/2015/5/21/making-a-numeric-type-in-swift.html
 
 
 */

//MARK: - Generics for D.R.Y

public protocol NumericType : Comparable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    var value :Double { set get }
    init(_ value: Double)
    var rangeDescription: BgRangeDescription { get }
}

public func + <T :NumericType> (lhs: T, rhs: T) -> T {
    return T(lhs.value + rhs.value)
}

public func - <T :NumericType> (lhs: T, rhs: T) -> T {
    return T(lhs.value - rhs.value)
}

public func < <T :NumericType> (lhs: T, rhs: T) -> Bool {
    return lhs.value < rhs.value
}

public func == <T :NumericType> (lhs: T, rhs: T) -> Bool {
    return lhs.value == rhs.value
}

public prefix func - <T: NumericType> (number: T) -> T {
    return T(-number.value)
}

extension NumericType {
    /// This returns the font and colour for use in the display according to the held bg value
    /// - Paramter isOldValue: `Bool` to indicate we have a value that is not the current one (and so return a grey colour).
    /// - Returns: a `Tuple` containing the colour of the range that our BG level sits in
    /// and the `UIFont`
    func displaySettings(isOldValue: Bool) -> (colour: UIColor, font: UIFont) {
        
        var retVal: (UIColor, UIFont) = (colour: UIColor.gray, font: UIFont.InRangeFont)
   
        guard !isOldValue else { return retVal }
        
        switch self.rangeDescription {
        case .urgentLow, .urgentHigh:
            retVal = (colour: ConstantsGlucoseChart.guidelineUrgentHighLow, font: UIFont.UrgentFont)
        case .low, .high:
            retVal = (colour: ConstantsGlucoseChart.glucoseNotUrgentRangeColor, font: UIFont.NonUrgentFont)
        case .inRange:
            retVal = (colour: ConstantsGlucoseChart.glucoseInRangeColor, font: UIFont.InRangeFont)
        case .rangeNR:
            retVal = (colour: UIColor.gray, font: UIFont.InRangeFont)
        case .special:
            retVal = (colour: UIColor(red: 0.857, green: 0.821, blue: 0.720, alpha: 1.00), font: UIFont.InRangeFont)
        default:
            break
        }
        return retVal
    }
}

//MARK: - mmol/L

/// UK units.
///
/// Uses `Double` as a base to accomodate the fractions

public struct MMOLL :NumericType {
    
    public var value :Double
    public init(_ value: Double) {
        self.value = value
    }
    
    public init(_ mgdlValue: MGDL) {
        self.value = mgdlValue.value
    }
    
    /// The range of the users BG level that should be considered urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of 0 ... urgentLowMarkValue`
    public var urgentLowRange: Range<MMOLL> {
        return Range(uncheckedBounds: (0, MMOLL(UserDefaults.standard.urgentLowMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered low but non-urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `urgentLowMarkValue` ... `urgentLowMarkValue`
    public var lowRange: Range<MMOLL> {
        return Range(uncheckedBounds: (MMOLL(UserDefaults.standard.urgentLowMarkValue.mgdlToMmol()), MMOLL(UserDefaults.standard.lowMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered nicely in range (for once! :)) )
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `lowMarkValue` ... `highMarkValue`
    public var inRange: Range<MMOLL> {
        return Range(uncheckedBounds: (MMOLL(UserDefaults.standard.lowMarkValue.mgdlToMmol()), MMOLL(UserDefaults.standard.highMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `highMarkValue` ... `urgentHighMarkValue`
    public var highRange: Range<MMOLL> {
        return Range(uncheckedBounds: (MMOLL(UserDefaults.standard.highMarkValue.mgdlToMmol()), MMOLL(UserDefaults.standard.urgentHighMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `urgentHighMarkValue` ... `∞`
    public var urgentHighRange: Range<MMOLL> {
        return Range(uncheckedBounds: (MMOLL(UserDefaults.standard.urgentHighMarkValue.mgdlToMmol()), MMOLL(Double.greatestFiniteMagnitude)))
    }
    
    
    
    /// Converts the current value to mg/dL
    var inMgDl: MGDL {
        return MGDL(value.mmolToMgdl())
    }
    
    /// Returns a `String` of the current value in the form `12.3`
    var string: String {
        return String(format:"%.1f", self.value)
    }
    
    
    /// Returns a `String` of the current value with the units, in the form `12.3 mmol/L`
    var unitisedString: String {
        return self.string + " " + Texts_Common.mmol
    }
    
    /// Returns a `BgRangeDescription` according to the current value of `self`
    public var rangeDescription: BgRangeDescription {
        
        if urgentLowRange.contains(self) {
            return .urgentLow
        } else if lowRange.contains(self) {
            return .low
        } else if inRange.contains(self) {
            return .inRange
        } else if highRange.contains(self) {
            return .high
        } else if urgentHighRange.contains(self){
            return .urgentHigh
        }
        return .notUrgent
    }
}

extension MMOLL :ExpressibleByIntegerLiteral {
    public init(integerLiteral: IntegerLiteralType) {
        self.init(Double(integerLiteral))
    }
}

extension MMOLL :ExpressibleByFloatLiteral {
    public init(floatLiteral: FloatLiteralType) {
        self.init(Double(floatLiteral))
    }
}

//MARK: - mg/dL

/// US/European units.

public struct MGDL :NumericType {
    public var value :Double
    public init(_ value: Double) {
        self.value = value
    }
    
    /// Returns a `String` of the current value in the form `123`
    var string: String {
        return String(format:"%.0f", self.value)
    }
    
    /// The range of the users BG level that should be considered urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of 0 ... `Int(urgentLowMarkValue)`
    var urgentLowRange: Range<MGDL> {
        return Range(uncheckedBounds: (0, MGDL(UserDefaults.standard.urgentLowMarkValue)))
    }
    
    /// The range of the users BG level that should be considered low but non-urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(urgentLowMarkValue)` ... `Int(urgentLowMarkValue)`
    var lowRange: Range<MGDL> {
        return Range(uncheckedBounds: (MGDL(UserDefaults.standard.urgentLowMarkValue), MGDL(UserDefaults.standard.lowMarkValue)))
    }
    
    /// The range of the users BG level that should be considered nicely in range (for once! :)) )
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(lowMarkValue)` ... `Int(highMarkValue)`
    var inRange: Range<MGDL> {
        return Range(uncheckedBounds: (MGDL(UserDefaults.standard.lowMarkValue), MGDL(UserDefaults.standard.highMarkValue)))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(highMarkValue)` ... `Int(urgentHighMarkValue)`
    var highRange: Range<MGDL> {
        return Range(uncheckedBounds: (MGDL(UserDefaults.standard.highMarkValue), MGDL(UserDefaults.standard.urgentHighMarkValue)))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(urgentHighMarkValue)` ... `Int(∞)`
    var urgentHighRange: Range<MGDL> {
        return Range(uncheckedBounds: (MGDL(UserDefaults.standard.urgentHighMarkValue), MGDL(Double.greatestFiniteMagnitude)))
    }
    
    /// Returns a `BgRangeDescription` according to the current value of `self`
    public var rangeDescription: BgRangeDescription {
        
        if urgentLowRange.contains(self) {
            return .urgentLow
        } else if lowRange.contains(self) {
            return .low
        } else if inRange.contains(self) {
            return .inRange
        } else if highRange.contains(self) {
            return .high
        } else if urgentHighRange.contains(self){
            return .urgentHigh
        }
        return .notUrgent
    }
    
    /// Converts the current value to mmol/dL
    var inMmolL: MMOLL {
        return MMOLL(value.mgdlToMmol())
    }
    
    /// Returns a `String` of the current value with the units, in the form `12.3 mg/dL`
    var unitisedString: String {
        return self.string + Texts_Common.mgdl
    }
}

extension MGDL: ExpressibleByIntegerLiteral {
    public init(integerLiteral: IntegerLiteralType) {
        self.init(Double(integerLiteral))
    }
}

extension MGDL: ExpressibleByFloatLiteral {
    public init(floatLiteral: FloatLiteralType) {
        self.init(Double(floatLiteral))
    }
}

/** This is a struct to allow for BG level info to be passed around when there is no `NSManagedObject` available
 e.g. when the user is panning.
 
 It provides a way of not having to hold onto `NSManagedObject`s when traversing the logic of the `BGView`.
 */
public struct UniversalBGLevel {
    
    // Presumably there is a way of passing the BG object around but this struct is a lazy way out of
    // reverse engineering the panning of the chart. It provides some convenience functions too.
    
    private var _mmoll: MMOLL = 0.0
    private var _mgdl: MGDL = 0.0
    
    /// The mmol/L of the BG level.
    ///
    /// Setting this will update the `private` `ivar` holding the mg/dL value.
    /// This class can be used as a converter between units if desired.
    public var mmoll: MMOLL {
        set {
            _mmoll = newValue
            _mgdl = _mmoll.inMgDl
        }
        get {
            return _mmoll
        }
    }
    
    /// The mg/dL of the BG level.
    ///
    /// Setting this will update the `private` `ivar` holding the mmol/L value.
    /// This class can be used as a converter between units if desired.
    public var mgdl: MGDL {
        set {
            _mgdl = newValue
            _mmoll = _mgdl.inMmolL
        }
        get {
            return _mgdl
        }
    }
    
    /// The time stamp of the BG Level
    public var timestamp: Date
    
    /// Returns a `true` if the `timeStamp` is older than 90 seconds.
    var isOld: Bool {
        return UniversalBGLevel.isOld(_date: timestamp)
    }
    
    /// Static `func` to return if a given `Date` is older than 1 minute 30" - i.e. it's a BG level that's out of date.
    static func isOld(_date: Date) -> Bool {
        return Date().timeIntervalSince(_date) > 89
    }
    
    init(_timestamp: Date = Date(), _mmoll: MMOLL? = nil, _mgdl: MGDL? = nil) {
        
        timestamp = _timestamp
        
        if let __mmoll = _mmoll {
            mmoll = __mmoll
        }
        
        if let __mgdl = _mgdl {
            mgdl = __mgdl
        }
    }
}
