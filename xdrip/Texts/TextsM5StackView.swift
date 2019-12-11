import Foundation


class Texts_M5StackView {
    
    static private let filename = "M5StackView"
    
    static let screenTitle: String = {
        return NSLocalizedString("screenTitle", tableName: filename, bundle: Bundle.main, value: "M5Stack", comment: "when M5 stack list is shown, title of the view")
    }()
     
    static let authenticationFailureWarning: String = {
        return NSLocalizedString("authenticationFailureWarning", tableName: filename, bundle: Bundle.main, value: "Authentication to M5Stack Failed, either set the pre-configured password in the Settings, or, if the M5Stack does not have a preconfigured password then reset the M5Stack. M5Stack will disconnect now. You can make a new attempt by clicking ", comment: "in case M5Stack authentication failed")
    }()
    
    static let blePasswordMissingWarning: String = {
        return NSLocalizedString("blePasswordMissingWarning", tableName: filename, bundle: Bundle.main, value: "You need to set the password in the Settings", comment: "in case M5Stack authentication failed, and M5Stack is expecting user configured password")
    }()
    
    static let m5StackResetRequiredWarning: String = {
        return NSLocalizedString("m5StackResetRequiredWarning", tableName: filename, bundle: Bundle.main, value: "You need to reset the M5Stack in order to get a new temporary password. When done click'", comment: "in case M5Stack authentication failed, and M5Stack is generating a random password")
    }()
    
    static let m5StackSoftWareHelpCellText: String = {
        return NSLocalizedString("m5StackSoftWareHelpCellText", tableName: filename, bundle: Bundle.main, value: "Where to find M5Stack software ?", comment: "In list of M5Stacks, the last line allows to show info where to find M5Stack software, this is the text in the cell")
    }()
    
    static let m5StackSoftWareHelpText: String = {
        return NSLocalizedString("m5StackSoftWareHelpText", tableName: filename, bundle: Bundle.main, value: "Go to", comment: "this is the text shown when clicking the cell 'where to find M5Stack software'")
    }()

}

