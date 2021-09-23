import Foundation

/// all texts for Settings Views related texts
class Texts_ExportView {
    static private let filename = "SettingsViews"
    
    // MARK: -
    
    static let screenTitle: String = {
        return NSLocalizedString("settingsviews_settingsexport", tableName: filename, bundle: Bundle.main, value: "Data Export", comment: "shown on top of the first settings screen, literally 'Settings'")
    }()
   
    static let exportBtn: String = {
        return NSLocalizedString("settingsviews_settingsexportbtn", tableName: filename, bundle: Bundle.main, value: "Export data to JSON", comment: "shown on top of the first settings screen, literally 'Settings'")
    }()

}

