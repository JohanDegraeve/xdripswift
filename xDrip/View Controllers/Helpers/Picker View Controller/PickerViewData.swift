import Foundation

/// defines data typically available in a view that allows user to pick from a list : list of items, selected item, title, cancel lable, ok or add label, function to call when pressing cancel, function to call button when pressing add button
public class PickerViewData {
    var mainTitle: String?
    var subTitle: String?
    var data: [String]
    var selectedRow: Int
    var actionTitle: String?
    var cancelTitle: String?
    var actionHandler: (_ index: Int) -> Void
    var cancelHandler: (() -> Void)?
    var didSelectRowHandler: ((Int) -> Void)?
    var priority: PickerViewPriority?
    var fullScreen: Bool?

    /// initializes PickerViewData.
    /// - parameters:
    ///     - withMainTitle : if present, then a larger sized main title must be shown on top of the picker, example "High Alert" must be shown in bigger font
    ///     - withSubTitle : example "Select Snooze Period" , can be in smaller font
    ///     - withData : list of strings to select from
    ///     - selectedRow : default selected row in withData
    ///     - actionButtonText : text to show in the ok button, eg "Ok" or "Add"
    ///     - cancelButtonText : text to show in the cancel button, eg "Cancel"
    ///     - onActionClick : closure to run when user clicks the actionButton
    ///     - onCancelClick : closure to run when user clicks the cancelButton
    ///     - didSelectRowHandler  : closure to run when user selects a row, even before clicking ok or cancel. Can be useful eg to play a sound
    ///     - fullScreen: true if to be displayed over a full screen view without nagivation controller
    init(withMainTitle mainTitle: String?, withSubTitle subTitle: String?, withData data: [String], selectedRow: Int?, withPriority priority: PickerViewPriority?, actionButtonText actionTitle: String?, cancelButtonText cancelTitle: String?, isFullScreen fullScreen: Bool? = false, onActionClick actionHandler: @escaping ((_ index: Int) -> Void), onCancelClick cancelHandler: (() -> Void)?, didSelectRowHandler: ((Int) -> Void)?) {
        self.mainTitle = mainTitle
        self.subTitle = subTitle
        self.data = data
        self.selectedRow = selectedRow != nil ? selectedRow! : 0
        self.actionTitle = actionTitle
        self.cancelTitle = cancelTitle
        self.actionHandler = actionHandler
        self.cancelHandler = cancelHandler
        self.didSelectRowHandler = didSelectRowHandler
        self.priority = priority
        self.fullScreen = fullScreen
    }
}

/// priority to apply in the pickerview. High can use other colors and or size, Up to the pickerview
public enum PickerViewPriority {
    case normal
    case high
}
