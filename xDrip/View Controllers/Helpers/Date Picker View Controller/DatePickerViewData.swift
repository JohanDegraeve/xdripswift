import UIKit

/// defines data typically available in a view that allows user to pick a date
public class DatePickerViewData {
    var mainTitle: String?
    var subTitle: String?
    var okTitle: String?
    var cancelTitle: String?
    var okHandler: (_ date: Date) -> Void
    var cancelHandler: (() -> Void)?
    var datePickerMode: UIDatePicker.Mode
    var date: Date?
    var minimumDate: Date?
    var maximumDate: Date?
    var fullScreen: Bool?
    
    /// initializes DataPickerViewData.
    /// - parameters:
    ///     - withMainTitle : if present, then a larger sized main title must be shown on top of the picker, example "High Alert" must be shown in bigger font
    ///     - withSubTitle : example "Select Snooze Period" , can be in smaller font
    ///     - okButtonText : text to show in the ok button, eg "Ok" or "Add", default "Ok"
    ///     - cancelButtonText : text to show in the cancel button, eg "Cancel", default "Cancel"
    ///     - okHandler : closure to run when user clicks the okButton
    ///     - cancelHandler : closure to run when user clicks the cancelButton
    ///     - date : default date to set
    ///     - minimuDate : minimum allowed date that user can set
    ///     - maximumDate : maximum allowed date that user can set
    ///     - datePickerMode : DatePickerMode to use
    ///     - fullScreen: true if to be displayed over a full screen view without nagivation controller
    init(withMainTitle mainTitle: String?, withSubTitle subTitle: String?, datePickerMode: UIDatePicker.Mode, date: Date?, minimumDate: Date?, maximumDate: Date?, okButtonText okTitle: String?, cancelButtonText cancelTitle: String?, isFullScreen fullScreen: Bool? = false, onOkClick okHandler: @escaping ((_ date: Date) -> Void), onCancelClick cancelHandler: (() -> Void)?) {
        self.mainTitle = mainTitle
        self.subTitle = subTitle
        self.okTitle = okTitle
        self.cancelTitle = cancelTitle
        self.okHandler = okHandler
        self.cancelHandler = cancelHandler
        self.datePickerMode = datePickerMode
        self.date = date
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.fullScreen = fullScreen
    }
}
