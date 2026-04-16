import UIKit

extension UIAlertController {
    
    /// creates a UIAlertController of type alert with a title and message and adds an ok button, nothing else
    /// - parameters:
    ///     - title : title, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - message : message, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - actionHandler : optional closure which will be executed when user clickx ok, without in- output
    convenience init(title:String?, message:String?, actionHandler: (() -> Void)?) {

        self.init(title: title, message: message, preferredStyle: .alert)

        addAction(UIAlertAction(title: Texts_Common.Ok, style: .default, handler: { (action:UIAlertAction) in
            if let actionHandler = actionHandler {actionHandler()}
        }))
    }
    
    /// creates a UIAlertController of type alert with a title and message and adds an ok button and cancel button. Text in Ok button can be canged
    /// - parameters:
    ///     - title : title, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - message : message, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - actionHandler : optional closure which will be executed when user clickx ok, without in- output
    ///     - actionTitle : text for ok button
    convenience init(title:String?, message:String?, actionTitle: String, actionHandler: (() -> Void)?) {
        
        self.init(title: title, message: message, preferredStyle: .alert)
        
        addAction(UIAlertAction(title: actionTitle, style: .default, handler: { (action:UIAlertAction) in
            if let actionHandler = actionHandler {actionHandler()}
        }))
        
        // add cancel button
        addAction(UIAlertAction(title: Texts_Common.Cancel, style: .cancel, handler: nil))

    }
    
    /// creates a UIAlertController of type alert with a title and message and adds an ok button and a cancel button, if ok click then the actionHandler is executed, if cancel clicked then the cancelhandler which is optional
    /// - parameters:
    ///     - title : title, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - message : message, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - actionHandler : closure with no input parameters and no result, will be executed when user clicks ok
    ///     - cancelHandler : closure with no input parameters and no result, will be executed when user clicks cancel
    convenience init(title:String?, message:String?, actionHandler: @escaping (() -> Void), cancelHandler: (() -> Void)?) {
        
        self.init(title: title, message: message, preferredStyle: .alert)
        
        // add action for when user clicks ok
        addAction(UIAlertAction(title: Texts_Common.Ok, style: .default, handler: { (action:UIAlertAction) in
            actionHandler()
        }))
        
        // add action for when user clicks cancel
        addAction(UIAlertAction(title: Texts_Common.Cancel, style: .cancel, handler: { (action:UIAlertAction) in
            if let cancelHandler = cancelHandler {cancelHandler()}
        }))
    }
    
    /// creates a UIAlertController of type alert, with a textField and two actions. One to confirm the entered text (action button), another one to cancel (cancel button)
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
    
    /// creates a UIAlertController of type actionSheet.
    /// - parameters:
    ///     - title : title, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - message : message, optional, used in init(title: title, message: message, preferredStyle: .alert)
    ///     - actions : dictionary of UIAlertAction's with style .default that will be added. The key is the title of the action, the value is the handler when the user clicks the action
    ///     - cancelAction : UIAlertAction of type cancel, tuple consisting of String which is the title and handler
    convenience init(title: String?, message: String?, actions: [String : ((UIAlertAction) -> Void)], cancelAction: (String, ((UIAlertAction) -> Void)?)) {
        
        self.init(title: title, message: message, preferredStyle: .actionSheet)
        
        // add each action of type default
        for (actionTitle, actionHandler) in actions {
            addAction(UIAlertAction(title: actionTitle, style: .default
                , handler: actionHandler))
        }
        
        // add the cancel action
        addAction(UIAlertAction(title: cancelAction.0, style: .cancel, handler: cancelAction.1))
        
    }
}
