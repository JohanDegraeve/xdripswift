import Foundation

public enum FontWeightType: Int, CaseIterable {
    
    case regular = 0
    case medium = 1
    case semibold = 2
    case bold = 3
    case light = 4
    
    var description: String {
        switch self {
        case .regular:
            return Texts_SettingsView.fontWeightRegular
        case .medium:
            return Texts_SettingsView.fontWeightMedium
        case .semibold:
            return Texts_SettingsView.fontWeightSemibold
        case .bold:
            return Texts_SettingsView.fontWeightBold
        case .light:
            return Texts_SettingsView.fontWeightLight
        }
    }
    
    var title: String {
        return description
    }
            
    func toUI() -> UIFont.Weight {
        return switch self {
        case .regular:
            UIFont.Weight.regular
        case .medium:
            UIFont.Weight.medium
        case .semibold:
            UIFont.Weight.semibold
        case .bold:
            UIFont.Weight.bold
        case .light:
            UIFont.Weight.light
        }
    }
    
}
