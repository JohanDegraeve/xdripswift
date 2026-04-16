//
//  DexcomBackfillStream.swift
//  xDrip
//
//  Created by Ivan Skoryk on 02.11.2020.
//  Copyright © 2020 Faifly. All rights reserved.
//

import Foundation

final class DexcomBackfillStream {
    struct BackFill {
        let glucose: Int
        let trend: Int
        let dexTime: Int
    }
    
    var data = Data()
    private var lastSequence = 0
    private var idx = 4
    
    
    func push(_ packet: Data) {
        guard !packet.isEmpty else { return }
        
        let thisSequence = packet[0]
        
        if thisSequence == lastSequence + 1 {
            lastSequence += 1
            
            for idx in 2 ..< packet.count {
                guard data.count < 1000 else {
                    return
                }
                data.append(packet[idx])
            }
        }
    }
    
    func decode() -> [BackFill] {
        var backfills: [BackFill] = []
        
        while idx < data.count {
            var dexTime: UInt32
            var glucose: UInt16
            var type: UInt8
            var trend: UInt8
            
            guard idx + 4 <= data.count - 1 else {
                idx = 0
                break
            }
            dexTime = Data(data[idx ..< idx + 4]).to(UInt32.self)
            idx += 4
            
            guard idx + 2 <= data.count - 1 else {
                idx = 0
                break
            }
            glucose = Data(data[idx ..< idx + 2]).to(UInt16.self)
            idx += 2
            
            guard idx <= data.count - 1 else {
                idx = 0
                break
            }
            type = data[idx]
            idx += 1
            
            guard idx <= data.count - 1 else {
                idx = 0
                break
            }
            trend = data[idx]
            idx += 1
            
            if let state = DexcomAlgorithmState(rawValue: type) {
                switch state {
                case .okay, .needsCalibration:
                    if dexTime != 0 {
                        backfills.append(
                            BackFill(glucose: Int(glucose), trend: Int(trend), dexTime: Int(dexTime))
                        )
                    }
                default:
                    continue
                }
            }
            
            if idx <= data.count - 1 {
                data = Data(data[idx ..< data.count])
            } else {
                data = Data()
            }
            idx = 0
        }
        
        return backfills
    }
}
