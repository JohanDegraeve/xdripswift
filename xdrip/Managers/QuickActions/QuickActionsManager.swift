//
//  QuickActionsManager.swift
//  xdrip
//
//  Created by Samuli Tamminen on 29.4.2022.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import UIKit

/// This enum defines actions that can be available at app icon's quick actions on iOS home screen
enum QuickActionType: String {
    case speakReadings = "speakReadings"
    case stopSpeakingReadings = "stopSpeakingReadings"
    
    /// Title is displayed in the long-press menu on the iOS home screen
    private var localizedTitle: String {
        switch self {
            case .speakReadings: return Texts_QuickActions.speakReadings
            case .stopSpeakingReadings: return Texts_QuickActions.stopSpeakingReadings
        }
    }
    
    /// Icon is displayed nex to the tile in the long-press menu on the iOS home screen
    private var icon: UIApplicationShortcutIcon {
        switch self {
            case .speakReadings: return .init(systemImageName: "speaker.wave.2")
            case .stopSpeakingReadings: return .init(systemImageName: "speaker.slash")
        }
    }
    
    /// Make a UIApplicationShortcutItem from the action
    var shortcutItem: UIApplicationShortcutItem {
        return UIApplicationShortcutItem(type: rawValue, localizedTitle: localizedTitle, localizedSubtitle: nil, icon: icon)
    }
}

class QuickActionsManager: NSObject {
    override init() {
        super.init()
        
        // add observer for speakReadings to update available quick actions when the setting is changed
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.speakReadings.rawValue, options: .new, context: nil)
      
        // Refresh initial state
        updateAvailableQuickActions()
    }
    
    /// Refresh available quick actions
    func updateAvailableQuickActions() {
        var shortcutItems = [UIApplicationShortcutItem]()
        
        if UserDefaults.standard.speakReadings {
            shortcutItems.append(QuickActionType.stopSpeakingReadings.shortcutItem)
        } else {
            shortcutItems.append(QuickActionType.speakReadings.shortcutItem)
        }
        
        UIApplication.shared.shortcutItems = shortcutItems
    }
    
    /// Perform the necessary action when user selects a quick action
    func handleQuickAction(_ actionType: QuickActionType) {
        switch actionType {
            case .speakReadings:
                UserDefaults.standard.speakReadings = true
            case .stopSpeakingReadings:
                UserDefaults.standard.speakReadings = false
        }
        
        // Refresh actions to represent current state
        updateAvailableQuickActions()
    }
    
    // MARK: - observe function
    
    // update available quick actions when the related setting is changed from elsewhere
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
            case UserDefaults.Key.speakReadings:
                updateAvailableQuickActions()
                
            default:
                break
        }
    }
}
