//
//  FollowerSettingsScreenFactory.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

/// Creates the dedicated child screen for every persisted follower source.
enum FollowerSettingsScreenFactory {
    static func make(
        source: FollowerDataSourceType,
        actions: SelectedFollowerActions
    ) -> SettingsScreen {
        switch source {
        case .nightscout:
            return NightscoutFollowerSettingsScreen.make()
        case .libreLinkUp, .libreLinkUpRussia:
            return LibreLinkUpFollowerSettingsScreen.make(source: source, actions: actions)
        case .dexcomShare:
            return DexcomShareFollowerSettingsScreen.make(actions: actions)
        case .medtrumEasyView:
            return MedtrumEasyViewFollowerSettingsScreen.make(actions: actions)
        case .calendar:
            return SharedCalendarFollowerSettingsScreen.make(refresh: actions.refresh)
        case .careLink:
            return CareLinkFollowerSettingsScreen.make()
        }
    }
}
