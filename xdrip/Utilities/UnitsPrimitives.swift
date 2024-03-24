//
//  Units Primitives.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
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

public func / <T: NumericType> (lhs: T, rhs: T) -> T {
    return T(lhs.value / rhs.value)
}

public func * <T: NumericType> (lhs: T, rhs: T) -> T {
    return T(lhs.value * rhs.value)
}

extension NumericType {
    /// This returns the font and colour for use in the display according to the held bg value
    /// - Paramter isOldValue: `Bool` to indicate we have a value that is not the current one (and so return a grey colour).
    /// - Returns: a `Tuple` containing the colour of the range that our BG level sits in
    /// and the `UIFont`
    func displaySettings(isOldValue: Bool) -> (colour: UIColor, font: UIFont) {
        
        var retVal: (UIColor, UIFont) = (colour: UIColor.gray, font: ConstantsUI.InRangeFont)
   
        guard !isOldValue else { return retVal }
        
        switch rangeDescription {
        case .urgent, .urgentHigh, .urgentLow:
            retVal = (colour: ConstantsGlucoseChart.glucoseUrgentRangeColor, font: ConstantsUI.UrgentFont)
        case .low, .high:
            retVal = (colour: ConstantsGlucoseChart.glucoseNotUrgentRangeColor, font: ConstantsUI.NonUrgentFont)
        case .inRange:
            retVal = (colour: ConstantsGlucoseChart.glucoseInRangeColor, font: ConstantsUI.InRangeFont)
        case .rangeNR:
            retVal = (colour: UIColor.gray, font: ConstantsUI.InRangeFont)
        case .special:
            retVal = (colour: UIColor(red: 0.857, green: 0.821, blue: 0.720, alpha: 1.00), font: ConstantsUI.InRangeFont)
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
public struct MMOLL: NumericType {
    
    public var value: Double
    
    public init(_ value: Double) {
        self.value = value
    }
    
    public init(_ value: Int) {
        self.value = Double(value)
    }
    
    public init(_ value: UInt32) {
        self.value = Double(value)
    }
    
    public init(_ value: CGFloat) {
        self.value = Double(value)
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
        //return to 2 decimal places since when dealing with values approaching 10.0 this will often round up, e.g. 9.98 becomes 10
        return String(format:"%.2f", self.value)
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




