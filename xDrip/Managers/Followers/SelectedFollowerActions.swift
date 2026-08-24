//
//  SelectedFollowerActions.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

/// User-requested actions for whichever follower source is currently selected.
/// The coordinator owns the managers. Settings only needs these three entry points.
struct SelectedFollowerActions {
    let refresh: () -> Void
    let logIn: () -> Void
    let logOut: () -> Void

    static let none = SelectedFollowerActions(refresh: {}, logIn: {}, logOut: {})
}
