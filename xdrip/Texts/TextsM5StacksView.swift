import Foundation

class Texts_M5StacksView {
    
    static private let filename = "M5StacksView"
    
    static let screenTitle: String = {
        return NSLocalizedString("screenTitle", tableName: filename, bundle: Bundle.main, value: "M5Stack List", comment: "when M5 stack list is shown, title of the view")
    }()
    
    static let m5StackSoftWareHelpCellText: String = {
        return NSLocalizedString("m5StackSoftWareHelpCellText", tableName: filename, bundle: Bundle.main, value: "Where to find M5Stack software ?", comment: "In list of M5Stacks, the last line allows to show info where to find M5Stack software, this is the text in the cell")
    }()

    static let m5StackSoftWareHelpText: String = {
        return NSLocalizedString("m5StackSoftWareHelpText", tableName: filename, bundle: Bundle.main, value: "Go to", comment: "this is the text shown when clicking the cell 'where to find M5Stack software'")
    }()
    
}
