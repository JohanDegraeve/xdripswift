import Foundation


class Texts_M5StackView {
    
    static private let filename = "M5StackView"
    
    static let m5StackViewscreenTitle: String = {
        return NSLocalizedString("m5StackViewscreenTitle", tableName: filename, bundle: Bundle.main, value: "M5Stack", comment: "when M5Stack list is shown, title of the view")
    }()
    
    static let m5StickCViewscreenTitle: String = {
        return NSLocalizedString("m5StickCViewscreenTitle", tableName: filename, bundle: Bundle.main, value: "M5StickC", comment: "when M5Stickc list is shown, title of the view")
    }()
     
    static let authenticationFailureWarning: String = {
        return NSLocalizedString("authenticationFailureWarning", tableName: filename, bundle: Bundle.main, value: "Authentication to M5Stack Failed, either set the pre-configured password in the Settings, or, if the M5Stack does not have a preconfigured password then reset the M5Stack. M5Stack will disconnect now. You can make a new attempt by clicking ", comment: "in case M5Stack authentication failed")
    }()
    
    static let blePasswordMissingWarning: String = {
        return NSLocalizedString("blePasswordMissingWarning", tableName: filename, bundle: Bundle.main, value: "You need to set the password in Settings", comment: "in case M5Stack authentication failed, and M5Stack is expecting user configured password")
    }()
    
    static let m5StackResetRequiredWarning: String = {
        return NSLocalizedString("m5StackResetRequiredWarning", tableName: filename, bundle: Bundle.main, value: "You need to reset the M5Stack in order to get a new temporary password. When done click'", comment: "in case M5Stack authentication failed, and M5Stack is generating a random password")
    }()
    
    static let m5StackSoftWhereHelpCellText: String = {
        return NSLocalizedString("m5StackSoftWhereHelpCellText", tableName: filename, bundle: Bundle.main, value: "Where to find the M5Stack software?", comment: "In m5Stack view, one line allows to show info where to find M5Stack software, this is the text in the cell")
    }()
    
    static let m5StickCSoftWhereHelpCellText: String = {
        return NSLocalizedString("m5StickCSoftWhereHelpCellText", tableName: filename, bundle: Bundle.main, value: "Where to find the M5StickC software?", comment: "In m5StickC view, one line allows to show info where to find M5Stack software, this is the text in the cell")
    }()
    
    static let m5StackSoftWareHelpText: String = {
        return NSLocalizedString("m5StackSoftWareHelpText", tableName: filename, bundle: Bundle.main, value: "Go To", comment: "this is the text shown when clicking the cell 'where to find M5Stack software'")
    }()

    static let deviceMustBeConnectedToPowerOff: String = {
        return NSLocalizedString("deviceMustBeConnectedToPowerOff", tableName: filename, bundle: Bundle.main, value: "M5Stack must be connected to be able to power it off", comment: "in case user tires to power off the M5Stack via xdrip but it's not connected")
    }()
    
    static let powerOff: String = {
        return NSLocalizedString("powerOff", tableName: filename, bundle: Bundle.main, value: "Power Off", comment: "cell text, to power off")
    }()
    
    static let powerOffConfirm: String = {
        return NSLocalizedString("powerOffConfirm", tableName: filename, bundle: Bundle.main, value: "Are you sure you want to power off the M5Stack?", comment: "user clicks power off in M5Stack view, confirmation is needed")
    }()
    
    static let connectToWiFi: String = {
        return NSLocalizedString("connectToWiFi", tableName: filename, bundle: Bundle.main, value: "Connect to Wifi", comment: "text for cell in settings view, connect to wifi yes or no")
    }()
}

