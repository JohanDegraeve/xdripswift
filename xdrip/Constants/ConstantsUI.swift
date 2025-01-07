import Foundation
import SwiftUI
import UIKit

enum ConstantsUI {
    // MARK: - SwiftUI Colors

    /// color for section headers
    static let sectionHeaderColor = Color(UIColor.lightGray)
    
    /// color for section footer
    static let sectionFooterColor = Color(UIColor.lightGray)

    /// List background color
    static let listBackGroundUIColor = UIColor.black
    
    /// List background color
    static let listBackGroundColor = Color(listBackGroundUIColor)
    
    /// color for cancel or dismiss button
    static let dismissOrCancelColor = Color(UIColor.red)

    static let plusButtonColor = Color(UIColor.yellow)
    
    // MARK: - Swift UIKit Colors
    
    /// color for section titles in grouped table views, example in settings view
    static let tableViewHeaderTextColor = UIColor.lightGray
    
    /// color to use as background when a row is selected
    static let tableRowSelectedBackGroundColor = UIColor.darkGray
    
    /// color to use for disclosure indicator in settings views
    static let disclosureIndicatorColor = UIColor.gray
    
    /// segmentedControl font size
    static let segmentedControlFont = UIFont.systemFont(ofSize: 11)
    /// segmentedControl background color
    static let segmentedControlBackgroundColor = UIColor(white: 0.05, alpha: 1)
    /// segmentedControl border width
    static let segmentedControlBorderWidth: CGFloat = 0.0
    /// segmentedControl font color
    static let segmentedControlNormalTextColor = UIColor.gray
    /// segmentedControl font color when selected
    static let segmentedControlSelectedTextColor = UIColor.black
    /// segmentedControl background color when selected
    static let segmentedControlSelectedTintColor = UIColor.lightGray
    
    /// colors for lock screen button in toolbar
    static let screenLockIconColor = UIColor.gray
    
    /// value label font size when the screen is in normal operation mode
    static let valueLabelFontSizeNormal = UIFont.systemFont(ofSize: 80)
    /// value label font bigger size when the screen is in screen lock mode
    static let valueLabelFontSizeScreenLock = UIFont.systemFont(ofSize: 120)
    
    /// clock label font color. It shouldn't be too white or it could be distracting at night.
    static let clockLabelColor = UIColor.lightGray
    /// clock label font size (ideally should be set to the same as the bigger valueLabel font size
    static let clockLabelFontSize = UIFont.systemFont(ofSize: 120)
    
    /// time format for displaying just the hour
    static let timeFormatHoursOnly = "j"
    
    /// time format for displaying hours and minutes
    static let timeFormatHoursMins = "jj:mm"
    
    /// date format for displaying the full short date
    static let dateFormatDayMonthYear = "dd/MM/yyyy"
    
    /// string to be used to show am time if the user locale shows a 12 hour clock
    static let timeFormatAM = "am"
    
    /// string to be used to show pm time if the user locale shows a 12 hour clock
    static let timeFormatPM = "pm"
}
