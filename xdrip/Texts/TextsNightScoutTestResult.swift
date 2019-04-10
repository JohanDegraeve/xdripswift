import Foundation

class Texts_NightScoutTestResult {
    static private let filename = "NightScoutTestResult"
    
    static let verificationSuccessFulAlertTitle: String = {
        return NSLocalizedString("nightscouttestresult_verificationsuccessfulalerttitle", tableName: filename, bundle: Bundle.main, value: "Verification Successful", comment: "POP up after verifying nightscout credentials, to say that verification of url and api key were successful - this is the title")
    }()
    
    static let verificationSuccessFulAlertBody: String = {
        return NSLocalizedString("nightscouttestresult_verificationsuccessfulalertbody", tableName: filename, bundle: Bundle.main, value: "Your nightscout account was verified successfully.", comment: "POP up after verifying nightscout credentials, to say that verification of url and api key were successful - this is the body")
    }()

    static let verificationErrorAlertTitle: String = {
        return NSLocalizedString("nightscouttestresult_verificationerroralerttitle", tableName: filename, bundle: Bundle.main, value: "Verification Error", comment: "POP up after verifying nightscout credentials, to say that verification of url and api key was not successful - this is the title")
    }()
    
}
