import Foundation

/// all texts for DexcomShare related texts
class Texts_DexcomShareTestResult {
    static private let filename = "DexcomShareTestResult"
    
    static let verificationSuccessfulAlertTitle: String = {
        return NSLocalizedString("dexcomsharetestresult_verificationsuccessfulalerttitle", tableName: filename, bundle: Bundle.main, value: "Verification Successful", comment: "POP up after verifying DexcomShare credentials, to say that verification of url and password key were successful - this is the title")
    }()
    
    static let verificationSuccessfulAlertBody: String = {
        return NSLocalizedString("dexcomsharetestresult_verificationsuccessfulalertbody", tableName: filename, bundle: Bundle.main, value: "Your Dexcom Share account was verified successfully", comment: "POP up after verifying DexcomShare credentials, to say that verification of url and password were successful - this is the body")
    }()
    
    static let verificationErrorAlertTitle: String = {
        return NSLocalizedString("dexcomsharetestresult_verificationerroralerttitle", tableName: filename, bundle: Bundle.main, value: "Verification Error", comment: "POP up after verifying DexcomShare credentials, to say that verification of url and password was not successful - this is the title")
    }()
    
    static let authenticateMaxAttemptsExceeded: String = {
        return NSLocalizedString("dexcomsharetestresult_SSO_AuthenticateMaxAttemptsExceeed", tableName: filename, bundle: Bundle.main, value: "Maximum login attempts exceeded. Wait 10 minutes and try again.", comment: "if dexcom share login fails , too many attempts")
    }()
    
    static let uploadErrorWarning: String = {
        return NSLocalizedString("dexcomsharetestresult_uploadErrorWarning", tableName: filename, bundle: Bundle.main, value: "Dexcom Share Upload Error", comment: "If dexcom share upload fails, and info is giving to user, this is the title of the pop up")
    }()
    
    static let monitoredReceiverSNDoesNotMatch: String = {
        return NSLocalizedString("dexcomsharetestresult_monitored_receiver_sn_doesnotmatch", tableName: filename, bundle: Bundle.main, value: "The Dexcom Share Serial Number does not match the serial number for this account. Verify the Serial Number in the settings.", comment: "If dexcom share upload fails because serial number does not match for the account")
    }()
    
    static let monitoredReceiverNotAssigned1: String = {
        return NSLocalizedString("dexcomsharetestresult_monitored_receiver_not_assigned_1", tableName: filename, bundle: Bundle.main, value: "It seems that the Transmitter ID or serial number", comment: "If serial number is not assigned to the account, this is the 1st part in a series of 3 to form a complete sentence")
    }()
    
    static let monitoredReceiverNotAssigned2: String = {
        return NSLocalizedString("dexcomsharetestresult_monitored_receiver_not_assigned_2", tableName: filename, bundle: Bundle.main, value: "is not assigned to", comment: "If serial number is not assigned to the account, this is the 2nd part in a series of 3 to form a complete sentence")
    }()
    
    static let monitoredReceiverNotAssigned3: String = {
        return NSLocalizedString("dexcomsharetestresult_monitored_receiver_not_assigned_3", tableName: filename, bundle: Bundle.main, value: "UUse the official Dexcom app to register the Transmitter (G5) or Share receiver (G4)\r\n\r\nYou are possibly just using the wrong URL, verify the setting 'Use US URL?'", comment: "If serial number is not assigned to the account, this is the 3rd part in a series of 3 to form a complete sentence")
    }()
    

}
