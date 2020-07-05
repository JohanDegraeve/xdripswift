import Foundation

class TextsLibreErrors {
    
    static private let filename = "LibreErrors"
    
    static let receivedDataIsNil: String = {
        return NSLocalizedString("receivedDataIsNil", tableName: filename, bundle: Bundle.main, value: "No data received from oop web server", comment: "In case oop web server responds without data")
    }()
    
    static let oOPWebServerError: String = {
        return NSLocalizedString("oOPWebServerError", tableName: filename, bundle: Bundle.main, value: "OOP Web Server error: ", comment: "This is for the notification that is created when there is an error while trying to reach the oop web server. The body text starts with this string, and will be followed by the error message received from iOS")
    }()
    
}
