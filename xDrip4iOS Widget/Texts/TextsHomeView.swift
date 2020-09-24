import Foundation

enum Texts_HomeView {
    
    static private let filename = "HomeView"
    
    static let ago:String = {
        return NSLocalizedString("ago", tableName: filename, bundle: Bundle.main, value: "ago", comment: "where it say how old the reading is, 'x minutes ago', literaly translation of 'ago'")
    }()
    
}

