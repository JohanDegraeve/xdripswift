import Foundation
import UIKit

enum ConstantsUI {
    
    /// color for section titles in grouped table views, example in settings view
    static let tableViewHeaderTextColor = UIColor.lightGray
    
    /// color to use as background when a row is selected
    static let tableRowSelectedBackGroundColor = UIColor.darkGray
    
    /// color to use for disclosure indicator in settings views
    static let disclosureIndicatorColor = UIColor.gray
    
    /// define the formatting to be used to style the segmented controls on the home screen
    static let segmentedControlFont = UIFont.systemFont(ofSize: 11)
    static let segmentedControlBackgroundColor = UIColor.init(white: 0.05, alpha: 1)
    static let segmentedControlBorderWidth: CGFloat = 0.0
    static let segmentedControlNormalTextColor = UIColor.gray
    static let segmentedControlSelectedTextColor = UIColor.black
    static let segmentedControlSelectedTintColor = UIColor.lightGray
    
    /// colors for lock screen button in toolbar
    static let screenLockIconColor = UIColor.gray
    
    /// value label font sizes
    static let valueLabelFontSizeNormal = UIFont.systemFont(ofSize: 90)
    static let valueLabelFontSizeScreenLock = UIFont.systemFont(ofSize: 120)
    
    /// clock label color and font size
    static let clockLabelColor = UIColor.lightGray
    static let clockLabelFontSize = UIFont.systemFont(ofSize: 120)
    
}
