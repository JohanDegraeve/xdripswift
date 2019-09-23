import Foundation

class Texts_M5StackView {
    
    static private let filename = "M5StackView"
    
    static let screenTitle: String = {
        return NSLocalizedString("screenTitle", tableName: filename, bundle: Bundle.main, value: "M5Stack", comment: "when specific M5 stack is shown, screen title")
    }()
    
    static let address: String = {
        return NSLocalizedString("address", tableName: filename, bundle: Bundle.main, value: "Address", comment: "when M5Stack is shown, title of the cell with the address")
    }()

    static let status: String = {
        return NSLocalizedString("status", tableName: filename, bundle: Bundle.main, value: "Status", comment: "when M5Stack is shown, title of the cell with the status")
    }()
    
    static let connected: String = {
        return NSLocalizedString("connected", tableName: filename, bundle: Bundle.main, value: "connected", comment: "when M5Stack is shown, connection status, connected")
    }()
    
    static let notConnected: String = {
        return NSLocalizedString("notConnected", tableName: filename, bundle: Bundle.main, value: "Not Connected", comment: "when M5Stack is shown, connection status, not connected")
    }()
    
    static let alwaysConnect: String = {
        return NSLocalizedString("alwaysconnect", tableName: filename, bundle: Bundle.main, value: "Always Connect", comment: "text in button top right, by clicking, user says that device should always try to connect")
    }()
    
    static let donotconnect: String = {
        return NSLocalizedString("donotconnect", tableName: filename, bundle: Bundle.main, value: "Don't connect", comment: "text in button top right, this button will disable automatic connect")
    }()
    
    static let authenticationFailureWarning: String = {
        return NSLocalizedString("authenticationFailureWarning", tableName: filename, bundle: Bundle.main, value: "Authentication to M5Stack Failed, either set the pre-configured password in the Settings, or, if the M5Stack does not have a preconfigured password then reset the M5Stack", comment: "in case M5Stack authentication failed")
    }()
    
    static let blePasswordMissingWarning: String = {
        return NSLocalizedString("blePasswordMissingWarning", tableName: filename, bundle: Bundle.main, value: "You need to set the password in the Settings", comment: "in case M5Stack authentication failed, and M5Stack is expecting user configured password")
    }()
    
    static let m5StackResetRequiredWarning: String = {
        return NSLocalizedString("m5StackResetRequiredWarning", tableName: filename, bundle: Bundle.main, value: "You need to reset the M5Stack in order to get a new temporary password", comment: "in case M5Stack authentication failed, and M5Stack is generating a random password")
    }()

    static let m5StackAlias: String = {
        return NSLocalizedString("m5StackAlias", tableName: filename, bundle: Bundle.main, value: "Alias", comment: "M5Stack view, this is a name of an M5Stack assigned by the user, to recognize the device")
    }()
    
    static let selectAliasText: String = {
        return NSLocalizedString("selectAliasText", tableName: filename, bundle: Bundle.main, value: "Choose a name for this M5Stack, the name will be shown in the app and is easier for you to recognize", comment: "M5Stack view, when user clicks userdefinedname (alias) field")
    }()
    
    static let userdefinedNameAlreadyExists: String = {
        return NSLocalizedString("userdefinedNameAlreadyExists", tableName: filename, bundle: Bundle.main, value: "There is already an M5Stack with this name", comment: "M5Stack view, when user clicks userdefinedname (alias) field")
    }()
    
    //confirmDeletionM5Stack
    static let confirmDeletionM5Stack: String = {
        return NSLocalizedString("userdefinedNameAlreadyExists", tableName: filename, bundle: Bundle.main, value: "Do you want to delete M5Stack with ", comment: "M5Stack view, when user clicks the trash button - this is not the complete sentence, it will be followed either by 'name' or 'alias', depending on the availability of a userdefined name")
    }()
}
