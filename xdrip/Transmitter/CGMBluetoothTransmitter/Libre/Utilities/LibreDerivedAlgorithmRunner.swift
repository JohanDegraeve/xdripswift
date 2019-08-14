//
//  LibreDerivedAlgorithmRunner.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 18.10.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//
// adapted by Johan Degraeve for xdrip ios
import Foundation

public struct LibreDerivedAlgorithmParameters: Codable, CustomStringConvertible {
    public var slope_slope: Double
    public var slope_offset: Double
    public var offset_slope: Double
    public var offset_offset: Double
    public var isValidForFooterWithReverseCRCs: Int
    public var extraSlope : Double = 1
    public var extraOffset: Double = 0
    public var serialNumber: String?
    
    public var description: String {
        return "LibreDerivedAlgorithmParameters:: slopeslope: \(slope_slope), slopeoffset: \(slope_offset), offsetoffset: \(offset_offset), offsetSlope: \(offset_slope), extraSlope: \(extraSlope), extraOffset: \(extraOffset), isValidForFooterWithReverseCRCs: \(isValidForFooterWithReverseCRCs)"
    }
    
    public init(slope_slope: Double, slope_offset:Double, offset_slope: Double, offset_offset: Double, isValidForFooterWithReverseCRCs: Int, extraSlope: Double, extraOffset: Double) {
        self.slope_slope = slope_slope
        self.slope_offset = slope_offset
        self.offset_slope = offset_slope
        self.offset_offset = offset_offset
        self.isValidForFooterWithReverseCRCs = isValidForFooterWithReverseCRCs
        self.extraSlope = extraSlope
        self.extraOffset = extraOffset
    }
}

