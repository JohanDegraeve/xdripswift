import UIKit

/// functions that define the contents of a Section
///
/// The protocol defines the Section title, the text and detailedText to be shown in a cell of that secion,
/// the accessoryType (none, disclosure, detail button, detail disclosure button), the UIView to be shown if applicable (eg UISwitch), the nomber of rows in the Section
protocol SettingsViewModelProtocol {
    /// what title should be shown in a section
    /// - returns:
    /// the section title, optional, for section
    func sectionTitle() -> String?
    
    /// the text to be shown for a specific row in the Section
    /// - returns:
    ///     the text
    func text(index:Int) -> String
    
    /// the accessoryType to be shown for a specific row in the Section (none, disclosure, detail button, detail disclosure button)
    /// - returns:
    ///     the accessoryType
    func accessoryType(index:Int) -> UITableViewCell.AccessoryType
    
    /// the detailedText to be shown for a specific row in the Section
    /// - returns:
    ///     the detailedText corresponding to cel on index
    func detailedText(index:Int) -> String?
    
    /// used for adding a a view in a settings cell, for the moment only used for UISwitch (on/off)
    /// - returns:
    ///     a UIView, nil of no UIView to be shown (example see SettingsViewHealthKitSettingsViewModel)
    ///     reloadSection : should section be reloaded or not - example after setting nightscoutupload to true/false a section reload is required because other rows need to be shown/hidden respectively
    func uiView(index:Int) -> (view: UIView?, reloadSection: Bool)
    
    /// what's the number of rows in the section
    /// - returns:
    ///     number of rows in the section
    func numberOfRows() -> Int
    
    /// what should happen if a row is selected
    /// - parameters:
    ///     - index: index of selected row in the Section
    /// - returns:
    ///     a selectedRowAction
    func onRowSelect(index:Int) -> SelectedRowAction
}

/// alows to define what should happen if a user has selected a row in the Settings table.
///
/// Example if a text input is required, enum value is askText, with title, subtitle, actiontitle, ...
/// With those variables, a UIAlertController can be build, this needs to be done in the UIViewController
///
/// the goal is to move away the presentation from the model, meaning the model defines what needs to be displayed
/// and requested, but it's the viewcontroller that will decide how to request and display
enum SelectedRowAction {
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
    /// - actionHandler: code to execute when user confirms input, with text that was entered by user, text is not optional here
    /// - cancelHandler: code to execute when user cancels input
    /// TODO: is it ok to define title, message optional ?
    case askText (title:String?, message:String?, keyboardType:UIKeyboardType?, text:String?, placeHolder:String?, actionTitle:String?, cancelTitle:String?, actionHandler: ((_ text: String) -> Void), cancelHandler: (() -> Void)?)
    
    /// when clicked, the function parameter needs to be called
    ///
    /// example, the chosen unit, is either mgdl or mmol. When user clicks, there's no need to show pop up with the two options. Just switch immediately. The function would do that in this case (ie change the setting)
    case callFunction(function :(() -> Void))
    
    /// when clicked a list of items must be presented form which the user needs to pick one, for example transmitter type
    /// - title: title that can be shown when asking for input
    /// - data: array of strings, items from which user can select
    /// - selectedRow: preselected item, index 0 is the first element
    /// - actionTitle: text in the button that allows the user to confirm the input (Example 'Ok'), if nil then default value "Ok" will be used
    /// - cancelTitle: text in the button that allows the user to cancel the input (Example 'Cancel'), if nil then default value "Cancel" will be used
    /// - actionHandler: code to execute when user confirms input, with index of item that was selected by user, 0 = first element
    /// - cancelHandler: code to execute when user cancels input
    /// TODO: is it ok to define title, message optional ?
    case selectFromList (title:String?, data:[String], selectedRow:Int?, actionTitle:String?, cancelTitle:String?, actionHandler: ((_ index: Int) -> Void), cancelHandler: (() -> Void)?)
    
}

/* UITableViewCell.AccessoryType
 None. The cell does not have any accessory view. This is the default value.
 
 Disclosure indicator. Is a grey arrow, it usually opens a new table with settings
 When this element is present, users know they can tap anywhere in the row to see the next level in the hierarchy or the choices associated with the list item. Use a disclosure indicator in a row when selecting the row results in the display of another list. Don’t use a disclosure indicator to reveal detailed information about the list item; instead, use a detail disclosure button for this purpose.

 Detail Button. Is an i in a circle

 Detail disclosure button. Is a grey arrow and an i in a cirlce (it's a button and a disclosure)
 Users tap this element to see detailed information about the list item. (Note that you can use this element in views other than table views, to reveal additional details about something; see “Detail Disclosure Buttons” for more information.) In a table view, use a detail disclosure button in a row to display details about the list item. Note that the detail disclosure button, unlike the disclosure indicator, can perform an action that is separate from the selection of the row. For example, in Phone Favorites, tapping the row initiates a call to the contact; tapping the detail disclosure button in the row reveals more information about the contact.
 
 Checkmark. It's just a checkmark, a kind of v
 */
