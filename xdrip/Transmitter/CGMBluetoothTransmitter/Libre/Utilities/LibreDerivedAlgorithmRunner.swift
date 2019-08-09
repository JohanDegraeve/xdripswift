//
//  LibreDerivedAlgorithmRunner.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 18.10.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//

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




public class LibreDerivedAlgorithmRunner{
    private var params: LibreDerivedAlgorithmParameters
    init(_ params:LibreDerivedAlgorithmParameters) {
        self.params = params
    }
    /* Result:
     Parameters
     slope1: 0.09130434782608696
     offset1: -20.913043478260875
     slope2: 0.11130434782608696
     offset2: -20.913043478260875
     
     slope_slope: 1.5290519877675845e-05
     slope_offset: -0.0
     offset_slope: 0.0023746842175242366
     offset_offset: -20.913043478260875
     
     */
    
    
    // These three functions should be implemented by the client
    // wanting to do offline calculations
    // of glucose
    private func slopefunc(raw_temp: Int) -> Double{
        
        return self.params.slope_slope * Double(raw_temp) + self.params.offset_slope
        // rawglucose 7124: 0.1130434605
        //0.00001562292 * 7124 + 0.0017457784869033700
        
        // rawglucose 5816: 0.0926086812
        //0.00001562292 * 5816 + 0.0017457784869033700
        
        
    }
    
    private func offsetfunc(raw_temp: Int) -> Double{
        return self.params.slope_offset  * Double(raw_temp) + self.params.offset_offset
        //rawglucose 7124: -21.1304349
        //-0.00023267185 * 7124 + -19.4728806406
        // rawglucose 5816: -20.8261001202
        //-0.00023267185 * 5816 + -19.4728806406
    }
    
    
    public func GetGlucoseValue(from_raw_glucose raw_glucose: Int, raw_temp: Int) -> Double{
        return self.slopefunc(raw_temp: raw_temp) * Double(raw_glucose) + self.offsetfunc(raw_temp: raw_temp)
    }
    
    private func serializeAlgorithmParameters(_ params: LibreDerivedAlgorithmParameters) -> String{
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        var ret = ""
        
        do {
            let jsonData = try encoder.encode(params)
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                ret = jsonString
            }
        } catch {
            print("Could not serialize parameters: \(error.localizedDescription)")
        }
        
        return ret
    }
    
    public func SaveAlgorithmParameters(){
        let fm = FileManager.default
        
        
        guard let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print ("cannot construct url dir for writing parameters")
            return
        }
        
        let fileUrl = dir.appendingPathComponent("LibreParamsForCurrentSensor").appendingPathExtension("txt")
        
        print("Saving algorithm parameters to  \(fileUrl.path)")
        
        do{
            try serializeAlgorithmParameters(params).write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
        }  catch let error as NSError {
            print("Error: fileUrl failed to write to \(fileUrl.path): \n\(error)" )
            return
            
        }
    }
    public static func CreateInstanceFromParamsFile() -> LibreDerivedAlgorithmRunner?{
        let fm = FileManager.default
        
        guard let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print ("cannot construct url dir for writing parameters")
            return nil
        }
        
        let fileUrl = dir.appendingPathComponent("LibreParamsForCurrentSensor").appendingPathExtension("txt")
        let text: String
        do{
            text = try String(contentsOf: fileUrl, encoding: .utf8)
        } catch {
            print("")
            return nil
        }
        
        if let jsonData = text.data(using: .utf8) {
            let decoder = JSONDecoder()
            
            do {
                let params = try decoder.decode(LibreDerivedAlgorithmParameters.self, from: jsonData)
                
                return LibreDerivedAlgorithmRunner(params)
            } catch {
                print("Could not create instance: \(error.localizedDescription)")
            }
        } else {
            print("Did not create instance")
        }
        return nil
    }
    
}

