import Foundation

/// all Nightscout related texts
class TextsNightscout {
    static private let filename = "NightscoutTestResult"
    
    static let verificationSuccessfulAlertTitle: String = {
        return NSLocalizedString("nightscouttestresult_verificationsuccessfulalerttitle", tableName: filename, bundle: Bundle.main, value: "Verification Successful", comment: "POP up after verifying nightscout credentials, to say that verification of url and api key were successful - this is the title")
    }()
    
    static let verificationSuccessfulAlertBody: String = {
        return NSLocalizedString("nightscouttestresult_verificationsuccessfulalertbody", tableName: filename, bundle: Bundle.main, value: "Your Nightscout site was verified successfully.", comment: "POP up after verifying nightscout credentials, to say that verification of url and api key were successful - this is the body")
    }()

    static let verificationErrorAlertTitle: String = {
        return NSLocalizedString("nightscouttestresult_verificationerroralerttitle", tableName: filename, bundle: Bundle.main, value: "Verification Error", comment: "POP up after verifying nightscout credentials, to say that verification of url and api key was not successful - this is the title")
    }()
    
    static let warningAPIKeyOrURLIsnil: String = {
        return NSLocalizedString("warningAPIKeyOrURLIsnil", tableName: filename, bundle: Bundle.main, value: "Your Nightscout URL (and optionally API_SECRET or Token) must be set before you can run the test", comment: "in settings screen, user tries to test url and API Key but one of them is not set")
    }()
    
    static let nightscoutAPIKeyAndURLStartedTitle : String = {
        return NSLocalizedString("nightscoutAPIKeyAndURLStartedTitle", tableName: filename, bundle: Bundle.main, value: "Verifying...", comment: "in settings screen, user clicked test button for nightscout url and apikey - this is the title")
    }()
    
    static let nightscoutAPIKeyAndURLStartedBody : String = {
        return NSLocalizedString("nightscoutAPIKeyAndURLStartedBody", tableName: filename, bundle: Bundle.main, value: "Nightscout Verification Test Started\n\nThis message should automatically disappear shortly", comment: "in settings screen, user clicked test button for nightscout url and apikey - this is the body")
    }()
    
}
