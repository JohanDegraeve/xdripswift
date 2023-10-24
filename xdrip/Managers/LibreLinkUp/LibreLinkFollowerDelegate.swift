//
//  LibreLinkFollowerDelegate.swift
//  xdrip
//
//  Created by Paul Plant on 26/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// to be implemented for anyone who needs to receive information from a follower manager
protocol LibreLinkFollowerDelegate: AnyObject {
    
    /// to pass back follower data
    /// - parameters:
    ///     - followGlucoseDataArray : array of FollowGlucoseData, can be empty array, first entry is the youngest
    func libreLinkFollowerInfoReceived(followGlucoseDataArray: inout [LibreLinkBgReading])

}

