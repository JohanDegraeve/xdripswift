//
//  FollowerDelegate.swift
//  xdrip
//
//  Created by Paul Plant on 7/10/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// to be implemented for anyone who needs to receive information from a follower manager
protocol FollowerDelegate:AnyObject {
    
    /// to pass back follower data
    /// - parameters:
    ///     - followGlucoseDataArray : array of FollowGlucoseData, can be empty array, first entry is the youngest
    func followerInfoReceived(followGlucoseDataArray: inout [FollowerBgReading])

}
