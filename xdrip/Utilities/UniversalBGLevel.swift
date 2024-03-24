//
//  UniversalBGLevel.swift
//  xdrip
//
//  Created by Todd Dalton on 11/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK:  UNIVERSAL BLOOD GLUCOSE WRAPPER

/** This is a struct to allow for BG level info to be passed around when there is no `NSManagedObject` available
 e.g. when the user is panning.
 
It also is a suggestion for how to store BG levels in future releases. Having one `struct` for each reading
 means that all conversions are much easier - the `struct`, for example, can check the user's units settings
 and return a reading in that unit with only one call.
 */
public struct UniversalBGLevel {
    
    private var intMmoll: MMOLL = 0.0
    private var intMgDl: MGDL = 0.0
    
    /// The mmol/L of the BG level.
    ///
    /// Setting this will update the `private` `ivar` holding the mg/dL value.
    /// This class can be used as a converter between units if desired.
    public var mmoll: MMOLL {
        set {
            intMmoll = newValue
            intMgDl = intMmoll.inMgDl
        }
        get {
            return intMmoll
        }
    }
    
    /// The mg/dL of the BG level.
    ///
    /// Setting this will update the `private` `ivar` holding the mmol/L value.
    /// This class can be used as a converter between units if desired.
    public var mgdl: MGDL {
        set {
            intMgDl = newValue
            intMmoll = intMgDl.inMmolL
        }
        get {
            return intMgDl
        }
    }
    
    /// The time stamp of the BG Level
    public var timestamp: Date
    
    /// Returns a `true` if the `timeStamp` is older than 90 seconds.
    var isOld: Bool {
        return UniversalBGLevel.isOld(date: timestamp)
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
    static func isOld(date: Date) -> Bool {
        return Date().timeIntervalSince(date) > 89
    }
    
    /// Produces the `String` representation of the level in the user's preferred units with the unit itself.
    var unitisedString: String {
        if UserDefaults.standard.bloodGlucoseUnitIsMgDl {
            return mgdl.unitisedString
        } else {
            return mmoll.unitisedString
        }
    }
    
    /// `init` where the timestamp must be declared but the levels can be omitted
    init(timestamp: Date = Date(), mmoll: MMOLL? = nil, mgdl: MGDL? = nil) {
        
        self.timestamp = timestamp
        
        if let uwMmoll = mmoll {
            self.mmoll = uwMmoll
        } else {
            // set to zero, This will mean that if neither mg/dl or mmol/l are passed in then everything will be zero.
            self.mmoll = 0.0
        }
        
        if let uwMgdl = mgdl {
            self.mgdl = uwMgdl
        }
    }
    
    /// Convenience `init` to set the timestamp to now but the levels to zero
    init() {
        timestamp = Date()
        mmoll = 0.0
    }
    
    /// Convenience `init` to make a copy of another `UniversalBGLevel`
    init(anotherReading: UniversalBGLevel) {
        timestamp = anotherReading.timestamp
        mmoll = anotherReading.mmoll
    }
    
    /// This `init` is a convenience for just passing a BG level around that
    /// has units which are based on the user's preferences.
    ///
    /// If you were to pass in `6.8` when the `UserDefaults.standard.bloodGlucoseUnitIsMgDl` is `false`
    /// then you've correctly passed in 6.8mmol/dl, 122.4mg/dl.
    /// If you pass in `122.4` when the `UserDefaults.standard.bloodGlucoseUnitIsMgDl` is `true` then
    /// you'll get an instance of this `struct ` that correctly hold 122.4mg/dl and 6.8mmol/l.
    /// But pass `122.4` when it's `false` then you've accidently passed in a BG level that's far too high.
    init(timestamp: Date = Date(), value: Double) {
        
        self.timestamp = timestamp
        
        if UserDefaults.standard.bloodGlucoseUnitIsMgDl {
            // we assume the passed in double is in mg/dl
            self.mgdl = MGDL(value)
        } else {
            // we assume the passed in double is in mmol/l
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
