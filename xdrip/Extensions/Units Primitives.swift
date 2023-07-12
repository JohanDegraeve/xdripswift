//
//  Units Primitives.swift
//  xdrip
//
//  Created by Todd Dalton on 08/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation



/*
 
 These are so that we can specify what a double is, directly.
 So with these, a BG level can be written as
 
 MMOLL(6.7)
 MGDL(192)
 
 This allows for strict typing of BG levels and is used in BGView to check the level sent in.
 
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
public struct MmolL: NumericType {
    
    public var value :Double
    public init(_ value: Double) {
        self.value = value
    }
    
    public init(_ mgdlValue: MgDl) {
        self.value = mgdlValue.value
    }
    
    /// The range of the users BG level that should be considered urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of 0 ... urgentLowMarkValue`
    public var urgentLowRange: Range<MmolL> {
        return Range(uncheckedBounds: (0, MmolL(UserDefaults.standard.urgentLowMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered low but non-urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `urgentLowMarkValue` ... `urgentLowMarkValue`
    public var lowRange: Range<MmolL> {
        return Range(uncheckedBounds: (MmolL(UserDefaults.standard.urgentLowMarkValue.mgdlToMmol()), MmolL(UserDefaults.standard.lowMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered nicely in range (for once! :)) )
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `lowMarkValue` ... `highMarkValue`
    public var inRange: Range<MmolL> {
        return Range(uncheckedBounds: (MmolL(UserDefaults.standard.lowMarkValue.mgdlToMmol()), MmolL(UserDefaults.standard.highMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `highMarkValue` ... `urgentHighMarkValue`
    public var highRange: Range<MmolL> {
        return Range(uncheckedBounds: (MmolL(UserDefaults.standard.highMarkValue.mgdlToMmol()), MmolL(UserDefaults.standard.urgentHighMarkValue.mgdlToMmol())))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mmolDl>` of `urgentHighMarkValue` ... `∞`
    public var urgentHighRange: Range<MmolL> {
        return Range(uncheckedBounds: (MmolL(UserDefaults.standard.urgentHighMarkValue.mgdlToMmol()), MmolL(Double.greatestFiniteMagnitude)))
    }
    
    
    /// Converts the current value to mg/dL
    var inMgDl: MgDl {
        return MgDl(value.mmolToMgdl())
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

extension MmolL: ExpressibleByIntegerLiteral {
    public init(integerLiteral: IntegerLiteralType) {
        self.init(Double(integerLiteral))
    }
}

extension MmolL: ExpressibleByFloatLiteral {
    public init(floatLiteral: FloatLiteralType) {
        self.init(Double(floatLiteral))
    }
}

//MARK: - mg/dL

/// US/European units.

public struct MgDl :NumericType {
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
    var urgentLowRange: Range<MgDl> {
        return Range(uncheckedBounds: (0, MgDl(UserDefaults.standard.urgentLowMarkValue)))
    }
    
    /// The range of the users BG level that should be considered low but non-urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(urgentLowMarkValue)` ... `Int(urgentLowMarkValue)`
    var lowRange: Range<MgDl> {
        return Range(uncheckedBounds: (MgDl(UserDefaults.standard.urgentLowMarkValue), MgDl(UserDefaults.standard.lowMarkValue)))
    }
    
    /// The range of the users BG level that should be considered nicely in range (for once! :)) )
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(lowMarkValue)` ... `Int(highMarkValue)`
    var inRange: Range<MgDl> {
        return Range(uncheckedBounds: (MgDl(UserDefaults.standard.lowMarkValue), MgDl(UserDefaults.standard.highMarkValue)))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(highMarkValue)` ... `Int(urgentHighMarkValue)`
    var highRange: Range<MgDl> {
        return Range(uncheckedBounds: (MgDl(UserDefaults.standard.highMarkValue), MgDl(UserDefaults.standard.urgentHighMarkValue)))
    }
    
    /// The range of the users BG level that should be considered high but not urgent
    ///
    /// Accesses the `Userdefaults` to construct a `Range<mgDl>` of `Int(urgentHighMarkValue)` ... `Int(∞)`
    var urgentHighRange: Range<MgDl> {
        return Range(uncheckedBounds: (MgDl(UserDefaults.standard.urgentHighMarkValue), MgDl(Double.greatestFiniteMagnitude)))
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
    var inMmolL: MmolL {
        return MmolL(value.mgdlToMmol())
    }
    
    /// Returns a `String` of the current value with the units, in the form `12.3 mg/dL`
    var unitisedString: String {
        return self.string + Texts_Common.mgdl
    }
}

extension MgDl: ExpressibleByIntegerLiteral {
    public init(integerLiteral: IntegerLiteralType) {
        self.init(Double(integerLiteral))
    }
}

extension MgDl: ExpressibleByFloatLiteral {
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
    
    private var pMmollValue: MmolL = 0.0
    private var pMgdlValue: MgDl = 0.0
    
    /// The mmol/L of the BG level.
    ///
    /// Setting this will update the `private ivar` holding the mg/dL value.
    /// This class can be used as a converter between units if desired.
    public var mmollValue: MmolL {
        set {
            pMmollValue = newValue
            pMgdlValue = pMmollValue.inMgDl
        }
        get {
            return pMmollValue
        }
    }
    
    /// The mg/dL of the BG level.
    ///
    /// Setting this will update the `private` `ivar` holding the mmol/L value.
    /// This class can be used as a converter between units if desired.
    public var mgdlValue: MgDl {
        set {
            pMgdlValue = newValue
            pMmollValue = pMgdlValue.inMmolL
        }
        get {
            return pMgdlValue
        }
    }
    
    /// The time stamp of the BG Level
    public var timeStamp: Date
    
    /// Returns a `true` if the `timeStamp` is older than 90 seconds.
    var isOld: Bool {
        return UniversalBGLevel.isOld(_date: timeStamp)
    }
    
    /// Static `func` to return if a given `Date` is older than 1 minute 30" - i.e. it's a BG level that's out of date.
    static func isOld(_date: Date) -> Bool {
        return Date().timeIntervalSince(_date) > 89
    }
    
    init(aTimeStamp: Date = Date(), aMmollValue: MmolL? = nil, aMgdlValue: MgDl? = nil) {
        
        timeStamp = aTimeStamp
        
        if let aMmoll = aMmollValue {
            pMmollValue = aMmoll
        }
        
        if let aMgdl = aMgdlValue {
            mgdlValue = aMgdl
        }
    }
}
