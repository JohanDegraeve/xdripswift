//
//  DexcomG6CalibrationRxMessage.swift
//  xDrip
//
//  Created by Dmitry on 29.12.2020.
//  Copyright © 2020 Faifly. All rights reserved.
//

import Foundation

struct DexcomCalibrationRxMessage {
    
    let type: DexcomCalibrationResponseType?
    //35 00 00 552e
    init?(data: Data) {
        
        guard data.count >= 3 else { return nil }
        
        guard data.starts(with: .calibrateGlucoseRx) else { return nil }
        
        type = DexcomCalibrationResponseType(rawValue: data[2])
        
    }
    
    var accepted: Bool {
        
        return type == .okay || type == .secondCalibrationNeeded || type == .duplicate
        
    }
}
