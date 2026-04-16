import UIKit

/// alows to define what should happen if a user has selected a row in the Settings screen. Applicable to for example to first Setting screen, where there's just a list of Sections, and items which require basic actions.
///
/// available cases :
/// - nothing : nothing to do
/// - askText : text input is needed, eg to ask transmitter id
/// - callFunction : call a specific function (a closure in other words)
/// - selectFromList : select a value from a list, eg transmitter type
/// - performSegue : to go to another viewcontroller
///
/// the goal is to move away the presentation from the model, meaning the model defines what needs to be displayed and requested, but it's the viewcontroller that will decide how to request and display.
///
/// this goal isn't 100% reached
enum SettingsSelectedRowAction {
    
    /// do nothing at all
    case nothing
    
    /// ask for text. A variable of tpye UIKeyboardType is used here, this is just to indicate what type of input is asked. It doesn't necessarily mean the viewcontroller needs to use it.
    /// - title: title that can be shown when asking for input
    /// - message: message that can be shown when asking for input
    /// - keyboardType: value can be used to define what kind of input is expected. In the end it's up to the viewcontroller or view to define what kind of keyboard will be used
    /// - placeHolder to show in the textfield if text is nil
    /// - text to show in the textfield
    /// - actionTitle: text in the button that allows the user to confirm the input (Example 'Ok'), if nil then default value "Ok" will be used
    /// - cancelTitle: text in the button that allows the user to cancel the input (Example 'Cancel'), if nil then default value "Cancel" will be used
    /// - inputValidator : closure to execute to validate the input, input a string and returns either nil if validation was ok or a string giving the error message to show to the user if validation fails - if inputValidator = nil then not validation is done - if result is not nil, then actionHandler will not be executed
    /// - actionHandler: code to execute when user confirms input, with text that was entered by user, text is not optional here - actionHandler will not be executed if there's an inputValidator and that inputValidator returns false
    /// - cancelHandler: code to execute when user cancels input - if nil then no validation must be done
    case askText (title:String?, message:String?, keyboardType:UIKeyboardType?, text:String?, placeHolder:String?, actionTitle:String?, cancelTitle:String?, actionHandler: ((_ text: String) -> Void), cancelHandler: (() -> Void)?, inputValidator: ((String) -> String?)?)
    
    /// when clicked, the function parameter needs to be called
    ///
    /// example, the chosen unit, is either mgdl or mmol. When user clicks, there's no need to show pop up with the two options. Just switch immediately. The function would do that in this case (ie change the setting)
    case callFunction(function :(() -> Void))
	
	/// takes as argument a callback that when called returns a ProgressBarStatus
    /// - Important: Displays a progress bar, so all routies MUST call the callback or will result in an endless loading.
	case callFunctionAndShareFile(function: ((_ callback: @escaping ((_ progress: ProgressBarStatus<URL>?) -> Void)) -> Void))
    
    /// when clicked a list of items must be presented form which the user needs to pick one, for example transmitter type
    /// - title: title that can be shown when asking for input
    /// - data: array of strings, items from which user can select
    /// - selectedRow: preselected item, index 0 is the first element
    /// - actionTitle: text in the button that allows the user to confirm the input (Example 'Ok'), if nil then default value "Ok" will be used
    /// - cancelTitle: text in the button that allows the user to cancel the input (Example 'Cancel'), if nil then default value "Cancel" will be used
    /// - actionHandler: code to execute when user confirms input, with index of item that was selected by user, 0 = first element
    /// - cancelHandler: code to execute when user cancels input
    /// - didSelectRowHandler: code to execute when user selects an item before clicking ok or cancel, can be useful eg to play a selected sound so that user hears how it sounds
    case selectFromList (title:String?, data:[String], selectedRow:Int?, actionTitle:String?, cancelTitle:String?, actionHandler: ((_ index: Int) -> Void), cancelHandler: (() -> Void)?, didSelectRowHandler: ((_ index: Int) -> Void)?)
    
    /// performSegue to be done with specified identifier
    ///
    /// (it's not the right place to define this, not a clear split view/model)
    case performSegue(withIdentifier: String, sender: Any?)
    
    /// to show Info to user, eg licenseInfo, with a title and a message. If Ok is clicked, optional actionHandler is executed
    /// - parameters:
    ///     - title : pop up title
    ///     - message : pop up message
    ///     - actionHandler : will be executed when ok buttin is clicked
    /// typical a pop up with a title and the message
    case showInfoText(title: String, message: String, actionHandler: (() -> Void)? = nil)
    
    /// user confirmation is required to perform the actionHandler
    case askConfirmation(title: String?, message: String?, actionHandler: (() -> Void), cancelHandler: (() -> Void)?)
    
}

/* explanation UITableViewCell.AccessoryType
 None. The cell does not have any accessory view. This is the default value.
 
 Disclosure indicator. Is a grey arrow, it usually opens a new table with settings
 When this element is present, users know they can tap anywhere in the row to see the next level in the hierarchy or the choices associated with the list item. Use a disclosure indicator in a row when selecting the row results in the display of another list. Don’t use a disclosure indicator to reveal detailed information about the list item; instead, use a detail disclosure button for this purpose.
 
 Detail Button. Is an i in a circle
 
 Detail disclosure button. Is a grey arrow and an i in a cirlce (it's a button and a disclosure)
 Users tap this element to see detailed information about the list item. (Note that you can use this element in views other than table views, to reveal additional details about something; see “Detail Disclosure Buttons” for more information.) In a table view, use a detail disclosure button in a row to display details about the list item. Note that the detail disclosure button, unlike the disclosure indicator, can perform an action that is separate from the selection of the row. For example, in Phone Favorites, tapping the row initiates a call to the contact; tapping the detail disclosure button in the row reveals more information about the contact.
 
 Checkmark. It's just a checkmark, a kind of v
 */
