//
//  TimeZone.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 10/2/16.
//  Copyright © 2016 LoopKit Authors. All rights reserved.
//

import Foundation


extension TimeZone {
    static var currentFixed: TimeZone {
        return TimeZone(secondsFromGMT: TimeZone.current.secondsFromGMT())!
    }
}
