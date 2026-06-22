import UIKit

extension UIButton {
    
    /// set isEnabled to true
    public func enable() {
        isEnabled = true
    }
    
    /// set isEnabled to false
    public func disable() {
        isEnabled = false
    }

    /// apply the standard picker view action button style
    public func applyPickerActionButtonStyle() {
        titleLabel?.font = ConstantsPickerView.actionButtonFont
    }

    /// apply the standard picker view action button style to a configured button
    public func applyConfiguredPickerActionButtonStyle() {
        guard var configuration = configuration else {
            applyPickerActionButtonStyle()
            return
        }

        configuration.buttonSize = ConstantsPickerView.actionButtonConfigurationSize
        configuration.contentInsets = ConstantsPickerView.actionButtonContentInsets
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = ConstantsPickerView.actionButtonFont
            return outgoing
        }

        self.configuration = configuration
    }
}
