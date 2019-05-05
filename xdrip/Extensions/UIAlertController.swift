import UIKit

extension UIAlertController {
    /// presents UIAlertController in rootViewController, the alert will pop up no matter where the user is
    func presentInOwnWindow(animated: Bool, completion: (() -> Void)?) {
        let alertWindow = UIWindow(frame: UIScreen.main.bounds)
        alertWindow.rootViewController = UIViewController()
        alertWindow.windowLevel = UIWindow.Level.alert + 1;
        alertWindow.makeKeyAndVisible()
        alertWindow.rootViewController?.present(self, animated: animated, completion: completion)
    }
    
    /// simple pop up which display a title and message in UIAlertController and adds an ok button
    /// - parameters:
    ///     - title : title, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - message : message, optional, used in init(title: title, message: message, preferredStyle: .alert)
    convenience init(title:String?, message:String?) {

        self.init(title: title, message: message, preferredStyle: .alert)

        addAction(UIAlertAction(title: Texts_Common.Ok, style: .default, handler: nil))
    }
    

    
    /// textField will be added and two actions. One to confirm the entered text (action button), another one to cancel (cancel button)
    /// - parameters:
    ///     - title : title, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - message : message, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - keyboardType : keyboardType to use
    ///     - text : to use in the textField that will be added
    ///     - placeHolder : to use in the textField that will be added
    ///     - actionTitle : text for the action button, default comes from Texts_Common.Ok
    ///     - cancelTitle : text for the cancel button, default comes from Texts_Common.Cancel
    ///     - actionHandler : action to take when user clicks the action button, text is the text entered by the user
    ///     - cancelHandler : action to take when user clicks the cancel button.
    convenience init(title:String?, message:String?, keyboardType:UIKeyboardType?, text:String?, placeHolder:String?, actionTitle:String?, cancelTitle:String?, actionHandler: @escaping ((_ text: String) -> Void), cancelHandler: (() -> Void)?) {
        
        self.init(title: title, message: message, preferredStyle: .alert)
        
        addTextField { (textField:UITextField) in
            textField.placeholder = placeHolder
            textField.text = text
            if let keyboardType = keyboardType { textField.keyboardType = keyboardType }
        }
        
        // add actions for when user clicks the action button
        var Ok = actionTitle
        if Ok == nil { Ok = Texts_Common.Ok }
        var cancel = cancelTitle
        if cancel == nil { cancel = Texts_Common.Cancel }
        addAction(UIAlertAction(title: Ok!, style: .default, handler: { (action:UIAlertAction) in
            if let textFields = self.textFields {
                if let text = textFields[0].text {
                    actionHandler(text)
                } //if there's no text then there's no reason to call actionHandler
            } //if there's no text then there's no reason to call actionHandler
        }))
        
        // add actions for when user clicks the cancel button
        addAction(UIAlertAction(title: cancel!, style: .cancel, handler: (cancelHandler != nil) ? {(action:UIAlertAction) in cancelHandler!()}:nil))
    }
    
    /// UIDatePicker will be added, with ok and cancelhandler, date can be set, minimum and maximum date, actionhandler is called when user clicks the Ok button, it has a UIDatePicker as input
    /// - parameters:
    ///     - title : title, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - message : message, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - actionHandler : action to take when user clicks the action button, text is the text entered by the user
    ///     - cancelHandler : action to take when user clicks the cancel button, optional
    convenience init(title: String?, message: String?, datePickerMode:UIDatePicker.Mode, date:Date?, minimumDate:Date?, maximumDate:Date?, actionHandler: @escaping (UIDatePicker) -> (), cancelHandler: (() -> Void)?) {
        self.init(title: title, message: message, preferredStyle: .alert)
        
        let dateTimePicker = UIDatePicker()
        dateTimePicker.datePickerMode = datePickerMode
        dateTimePicker.minimumDate = minimumDate
        dateTimePicker.maximumDate = maximumDate
        if let date = date {dateTimePicker.setDate(date, animated: true)}
        
        self.view.addSubview(dateTimePicker)
        
        let cancelAction = UIAlertAction(title: Texts_Common.Cancel, style: .cancel) {(action) in}
        self.addAction(cancelAction)

        let okAction = UIAlertAction(title: Texts_Common.Ok, style: .default) { (action) in
            actionHandler(dateTimePicker)
        }
        self.addAction(okAction)

        let height:NSLayoutConstraint = NSLayoutConstraint(item: self.view, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 250)
        self.view.addConstraint(height);
    }
}
