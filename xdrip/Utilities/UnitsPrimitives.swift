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

// MARK: - UNIVERSAL BLOOD GLUCOSE WRAPPER
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
    
    /// Returns the reading in the users preferred units as a `Double`
    var levelInUserUnits: Double {
        return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? mgdl.value : mmoll.value
    }
    
    /// Returns the reading in users preferred units as a string
    var levelInUserUnitsString: String {
        if UserDefaults.standard.bloodGlucoseUnitIsMgDl {
            return String(format: "%0.0f", mgdl.value)
        } else {
            return String(format: "%0.2f", mmoll.value)
        }
    }
    
    /// Static `func` to return if a given `Date` is older than 1 minute 30" - i.e. it's a BG level that's out of date.
    static func isOld(_date: Date) -> Bool {
        return Date().timeIntervalSince(_date) > 89
    }
    
    /// Produces the `String` representation of the level in the user's preferred units.
    var unitisedString: String {
        if UserDefaults.standard.bloodGlucoseUnitIsMgDl {
            return mgdl.unitisedString
        } else {
            return mmoll.unitisedString
        }
    }
    
    /// `init` where the timestamp must be declared but the levels can be omitted
    init(_timestamp: Date = Date(), _mmoll: MMOLL? = nil, _mgdl: MGDL? = nil) {
        
        timestamp = _timestamp
        
        if let __mmoll = _mmoll {
            mmoll = __mmoll
        } else {
            mmoll = 0.0
        }
        
        if let __mgdl = _mgdl {
            mgdl = __mgdl
        }
    }
    
    /// Convenience `init` to set the timestamp to now but the levels to zero
    init() {
        timestamp = Date()
        mmoll = 0.0
    }
    
    /// Convenience `init` to make a copy of another `UniversalBGLevel`
    init(anotherLevel: UniversalBGLevel) {
        timestamp = anotherLevel.timestamp
        mmoll = anotherLevel.mmoll
    }
    
    /// This `init` is a convenience for just passing a BG level around that
    /// has units which are based on the user's preferences.
    ///
    /// If you were to pass in `6.8` when the `UserDefaults.standard.bloodGlucoseUnitIsMgDl` is `false`
    /// then you've correctly passed in 6.8mmol/dl, 122.4mg/dl.
    /// If you pass in `122.4` when the `UserDefaults.standard.bloodGlucoseUnitIsMgDl` is `false`
    /// then you've accidently passed in a BG level that's far too high.
    init(timestamp: Date = Date(), value: Double) {
        
        self.timestamp = timestamp
        
        if UserDefaults.standard.bloodGlucoseUnitIsMgDl {
            self.mgdl = MGDL(value)
        } else {
            self.mmoll = MMOLL(value)
        }
    }
}

// Enable comparisons with UniversalBGLevel
extension UniversalBGLevel {
    
    static func >(lhs: UniversalBGLevel, rhs: UniversalBGLevel) -> Bool {
        return lhs.mgdl > rhs.mgdl
    }
    
    static func <(lhs: UniversalBGLevel, rhs: UniversalBGLevel) -> Bool {
        return lhs.mgdl < rhs.mgdl
    }
    
    static func ==(lhs: UniversalBGLevel, rhs: UniversalBGLevel) -> Bool {
        return lhs.mgdl == rhs.mgdl
    }
    
    static func +=( lhs: inout UniversalBGLevel, rhs: UniversalBGLevel) {
        lhs.mgdl = MGDL(lhs.mgdl.value + rhs.mgdl.value)
    }
    
    static func -=( lhs: inout UniversalBGLevel, rhs: UniversalBGLevel) {
        lhs.mgdl = MGDL(lhs.mgdl.value - rhs.mgdl.value)
    }
    
    static func - (lhs: UniversalBGLevel, rhs: UniversalBGLevel) -> UniversalBGLevel {
        return UniversalBGLevel(timestamp: lhs.timestamp, value:lhs.levelInUserUnits - rhs.levelInUserUnits)
    }
    
    static func + (lhs: UniversalBGLevel, rhs: UniversalBGLevel) -> UniversalBGLevel {
        return UniversalBGLevel(timestamp: lhs.timestamp, value:lhs.levelInUserUnits.value + rhs.levelInUserUnits)
    }
}



// MARK: - RANGE BIN

/// This `struct` is used to hold the blood sugar levels in any particular hour..

struct BGRangeBin {
    
    /// For AGP reports we need the 10th, 25th,50th, 75th and 90th percentiles.
    struct Quartiles {
        /// 10th Percentile
        var Q10: UniversalBGLevel
        /// 25th Percentile
        var Q25: UniversalBGLevel
        /// 50th Percentile - not to be confused with the **average**.
        var Q50: UniversalBGLevel
        /// 75th Percentile
        var Q75: UniversalBGLevel
        /// 90th Percentile
        var Q90: UniversalBGLevel
        
        init() {
            Q10 = UniversalBGLevel()
            Q25 = UniversalBGLevel()
            Q50 = UniversalBGLevel()
            Q75 = UniversalBGLevel()
            Q90 = UniversalBGLevel()
        }
        
        /// The **median** is the same as the second quartile
        var median: UniversalBGLevel { return Q50 }
    }
    
    private (set) var highestLevel: UniversalBGLevel = UniversalBGLevel(_mmoll: MMOLL(0))
    
    private (set) var lowestLevel: UniversalBGLevel = UniversalBGLevel(_mmoll: MMOLL(999))
    
    private (set) var averageLevel: UniversalBGLevel = UniversalBGLevel(_mmoll: MMOLL(6.0))
    
    private (set) var isOnlyInitialised: Bool = true
    
    private(set) var accumulatedTotal: UniversalBGLevel = UniversalBGLevel(value: 0.0)
    
    private(set) var quartiles: Quartiles = Quartiles()
    
    /// This is the hour that this bin refers to.
    ///
    /// The default is zero, so by default this bin will
    /// be for results between 00:00 - 00:59
    var hour: Int = 0
    
    /// This UniversalBGLevel array holds the results in this bin's timeframe
    private (set) var levels:[UniversalBGLevel] = []
    
    /// If the timestamp of a `UniversalBGLevel` is within the `hour` that this
    /// bin is for, then the `count` and high/low/average levels will be adjusted
    /// if applicable.
    ///
    /// Returns a dicardable `Bool` to indicate if the level was "accepted".
    @discardableResult public mutating func addResultWithTimestampCheck(level: UniversalBGLevel) -> Bool {
 
        guard Calendar.current.component(.hour, from: level.timestamp) == hour else { return false }
        
        return addResult(level: level)
    }
    
    /// Adds a value to this bin. The `count` and high/low/average levels will be adjusted
    /// if applicable.
    ///
    /// Returns a dicardable `Bool` to indicate if the level was "accepted".
    @discardableResult public mutating func addResult(level: UniversalBGLevel) -> Bool {
        
        // Check to see if this new level will alter the range bounds
        if level < lowestLevel {
            lowestLevel = UniversalBGLevel(_timestamp: level.timestamp, _mmoll: level.mmoll)
        }
        
        if level > highestLevel {
            highestLevel = UniversalBGLevel(_timestamp: level.timestamp, _mmoll: level.mmoll)
        }
        
        levels.append(level)
        
        accumulatedTotal += level
        
        averageLevel = UniversalBGLevel(_timestamp: level.timestamp, _mmoll: MMOLL(accumulatedTotal.mmoll.value / Double(levels.count)))
        
        isOnlyInitialised = false
        
        return true
    }
    
    /// Calculate the quartiles Q1, 2 & 3
    mutating func calcQs() {
        
        guard !isOnlyInitialised, levels.count > 2 else { return }
        
        levels = levels.sorted { aBG, bBG in
            return aBG < bBG
        }
        
        func quartile(q: Double) -> UniversalBGLevel {
            let qSpot = (q / 100) * Double(levels.count)
            if ceil(qSpot) == floor(qSpot) {
                // whole number
                let med = (levels[Int(qSpot)].levelInUserUnits + levels[min(Int(qSpot) + 1, levels.count - 1)].levelInUserUnits) / 2
                return UniversalBGLevel(timestamp: levels[Int(qSpot)].timestamp, value: med)
            }
            return UniversalBGLevel(anotherLevel: levels[Int(qSpot)])
        }
        
        
        // --- Calculate Q10
        quartiles.Q10 = quartile(q: 10)
        // --- Calculate Q25
        quartiles.Q25 = quartile(q: 25)
        // --- Calculate Q50 aka median
        quartiles.Q50 = quartile(q: 50)
        // --- Calculate Q75
        quartiles.Q75 = quartile(q: 75)
        // --- Calculate Q90
        quartiles.Q90 = quartile(q: 90)
    }
}


