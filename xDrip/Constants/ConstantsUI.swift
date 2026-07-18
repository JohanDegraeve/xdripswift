import Foundation
import SwiftUI

enum ConstantsUI {
    // MARK: - SwiftUI Colors

    /// color for section headers
    static let sectionHeaderColor = Color(white: 0.67)

    /// color for section header icons in SwiftUI settings views
    static let settingsSectionHeaderIconColor = Color(red: 0.30, green: 0.55, blue: 0.75)
    
    /// List background color
    static let listBackGroundColor = Color.black

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

    /// Dot color used to identify glucose readings that were received through backfill.
    static let backfilledReadingIndicatorDotColor = Color.orange

    /// Dot size used to identify glucose readings that were received through backfill.
    static let backfilledReadingIndicatorDotSize: CGFloat = 5

    /// Muted red used for Settings parent row summaries when the child feature is disabled.
    static let rowTitleColorFalse = Color(red: 0.45, green: 0.18, blue: 0.18)

    /// dark red tint used for warning-style SwiftUI sections
    static let warningSectionBackgroundColor = Color(red: 0.20, green: 0.12, blue: 0.12)

    /// yellow-orange used for caution indicators that should be softer than urgent red
    static let cautionIndicatorColor = Color(red: 1.00, green: 0.68, blue: 0.08)

    /// common warning triangle color used inside warning/caution Settings banners
    static let warningBannerIndicatorColor = Color.yellow

    /// dark yellow-orange tint used for caution-style SwiftUI sections
    static let cautionSectionBackgroundColor = Color(red: 0.24, green: 0.18, blue: 0.05)
    
    static let plusButtonColor = Color.yellow
    
    /// color for section titles in grouped settings lists
    static let tableViewHeaderTextColor = Color(white: 0.67)

    /// color used for disclosure indicators in settings lists
    static let disclosureIndicatorColor = Color.gray
    
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
