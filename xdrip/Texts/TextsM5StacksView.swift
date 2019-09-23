import Foundation

class Texts_M5StacksView {
    
    static private let filename = "M5StacksView"
    
    static let screenTitle: String = {
        return NSLocalizedString("screenTitle", tableName: filename, bundle: Bundle.main, value: "M5Stack List", comment: "when M5 stack list is shown, title of the view")
    }()
}
