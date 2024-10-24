//
//  Profile+Nightscout.swift
//  xdrip
//
//  Created by Paul Plant on 23/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//


// Response from nightscoutUrl/api/v1/profile.json : NsProfile
// - id
// - store : NsProfileStore
//   - default : NsProfileStoreProfile
//     - carbratio [] : NsProfileStoreProfileValue
//       - timeAsSeconds
//       - time
//       - value
//     - dia
//     - sens []
//       - timeAsSeconds
//       - time
//       - value
//     - basal []
//       - timeAsSeconds
//       - time
//       - value
//     - units
//     - startDate
//     - defaultProfile
//     - enteredBy
//     - created_at: "2024-10-20T07:14:27.388Z"
//     - delay
//     - timezone
//     - carbs_hr
//     - target_low []
//       - timeAsSeconds
//       - time
//       - value
//     - target_high []
//       - timeAsSeconds
//       - time
//       - value


// MARK: JSON Structs Nightscout profile response

/// struct to define data.xxxxxx
struct NsProfileResponse: Codable {
    let id: String?
    let store: NsProfileStore?
}

/// struct to define data.store.xxxxxx
struct NsProfileStore: Codable {
    let profile: NsProfileStoreProfile?
}

/// struct to define data.store.profilename.xxxxxx
struct NsProfileStoreProfile: Codable {
    let carbRatio: [NsProfileStoreProfileValue]?
    let sens: [NsProfileStoreProfileValue]?
    let basal: [NsProfileStoreProfileValue]?
    let dia: Double?
    let units: String?
    let startDate: Date
    let timezone: String?
}

/// struct to define data.store.profilename.xxxxx.xxxxxx
struct NsProfileStoreProfileValue: Codable {
    let timeAsSeconds: Double?
    let time: TimeInterval?
    let value: Double?
}
