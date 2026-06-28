import Foundation
import SwiftUI
import UIKit

enum ConstantsUI {
    // MARK: - SwiftUI Colors

    /// color for section headers
    static let sectionHeaderColor = Color(UIColor.lightGray)

    /// color for section header icons in SwiftUI settings views
    static let settingsSectionHeaderIconColor = Color(red: 0.30, green: 0.55, blue: 0.75)
    
    /// color for section footer
    static let sectionFooterColor = Color(UIColor.lightGray)

    /// List background color
    static let listBackGroundUIColor = UIColor.black
    
    /// List background color
    static let listBackGroundColor = Color(listBackGroundUIColor)

    /// Background color for active rows in SwiftUI grouped lists.
    static let activeRowBackgroundColor = Color.green.opacity(0.24)

    /// Insets for the Bluetooth peripheral status banner row.
    static let bluetoothPeripheralStatusBannerRowInsets = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)

    /// Insets for the Bluetooth peripheral status action button row.
    static let bluetoothPeripheralStatusButtonRowInsets = EdgeInsets(top: 0, leading: 16, bottom: 13, trailing: 16)

    /// Extra bottom padding for SwiftUI section footers when grouped lists feel too compressed.
    static let listSectionFooterBottomPadding: CGFloat = 8

    /// Text color for SwiftUI grouped list section footers.
    static let listSectionFooterTextColor = Color(.colorSecondary)

    /// dark red tint used for warning-style SwiftUI sections
    static let warningSectionBackgroundColor = Color(red: 0.20, green: 0.12, blue: 0.12)
    
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

enum ConstantsSettingsPlaceholders {
    /// Shared example for settings rows that ask for an account username or email.
    static let usernamePlaceholder = "username/e-mail"

    /// Shared example for settings rows that ask for a password.
    static let passwordPlaceholder = "MyPassword123"
}
