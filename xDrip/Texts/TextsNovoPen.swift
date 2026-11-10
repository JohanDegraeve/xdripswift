import Foundation

/// all texts related to the NovoPen NFC reader
enum Texts_NovoPen {
    static private let filename = "Treatments"

    static let holdPenNearPhone: String = {
        return NSLocalizedString("novopen_holdPenNearPhone", tableName: filename, bundle: Bundle.main, value: "Hold the cap end of your NovoPen near the top of your iPhone", comment: "NFC system sheet prompt while waiting for the pen.")
    }()

    static let scanComplete: String = {
        return NSLocalizedString("novopen_scanComplete", tableName: filename, bundle: Bundle.main, value: "NovoPen scan complete", comment: "NFC system sheet message after the pen was read.")
    }()

    static let notAPen: String = {
        return NSLocalizedString("novopen_notAPen", tableName: filename, bundle: Bundle.main, value: "This is not a NovoPen", comment: "NFC system sheet message when the scanned tag is not a NovoPen.")
    }()

    static let scanFailed: String = {
        return NSLocalizedString("novopen_scanFailed", tableName: filename, bundle: Bundle.main, value: "NovoPen scan failed", comment: "NFC system sheet message when reading the pen failed.")
    }()

    static let readingDoses: String = {
        return NSLocalizedString("novopen_readingDoses", tableName: filename, bundle: Bundle.main, value: "Reading pen… %d doses", comment: "NFC system sheet message while reading the pen; %d is the number of doses received so far.")
    }()

    static let readIncomplete: String = {
        return NSLocalizedString("novopen_readIncomplete", tableName: filename, bundle: Bundle.main, value: "Read interrupted – scan again for the rest", comment: "Added to the result alert when the pen read was cut short.")
    }()

    static let importedDoses: String = {
        return NSLocalizedString("novopen_importedDoses", tableName: filename, bundle: Bundle.main, value: "Imported %d doses", comment: "Result alert after a pen scan; %d is the number of doses imported.")
    }()

    static let heldBackAirShot: String = {
        return NSLocalizedString("novopen_heldBackAirShot", tableName: filename, bundle: Bundle.main, value: "A small dose was held back as a possible air shot – scan again in a few minutes", comment: "Added to the result alert when the newest small dose was not imported yet because it may be an air shot.")
    }()

    static let skippedEntries: String = {
        return NSLocalizedString("novopen_skippedEntries", tableName: filename, bundle: Bundle.main, value: ", skipped %d error entries", comment: "Appended to the result alert; %d is the number of pen log entries that were errors.")
    }()

    static let addPen: String = {
        return NSLocalizedString("novopen_addPen", tableName: filename, bundle: Bundle.main, value: "Add pen", comment: "Settings menu: choose Bolus or Basal, then scan the NovoPen to add it.")
    }()

    static let penAdded: String = {
        return NSLocalizedString("novopen_penAdded", tableName: filename, bundle: Bundle.main, value: "Pen %1$@ added as %2$@", comment: "Alert after adding a NovoPen in settings; %1$@ is its serial number, %2$@ is Bolus or Basal.")
    }()

    static let penNotAdded: String = {
        return NSLocalizedString("novopen_penNotAdded", tableName: filename, bundle: Bundle.main, value: "Pen %@ is not added yet. Add it in Treatment settings, then scan again.", comment: "Result alert when a scanned NovoPen was never added; %@ is its serial number.")
    }()

    static let penNotAddedShort: String = {
        return NSLocalizedString("novopen_penNotAddedShort", tableName: filename, bundle: Bundle.main, value: "Pen not added yet", comment: "NFC system sheet message when the scanned NovoPen was never added in settings.")
    }()

    static let penKindBasal: String = {
        return NSLocalizedString("novopen_penKindBasal", tableName: filename, bundle: Bundle.main, value: "Basal", comment: "Button: this pen holds long-acting (basal) insulin.")
    }()

    static let scanPen: String = {
        return NSLocalizedString("novopen_scanPen", tableName: filename, bundle: Bundle.main, value: "Scan NovoPen", comment: "Accessibility label of the Treatments toolbar button that scans a NovoPen.")
    }()

    static let settingEnabled: String = {
        return NSLocalizedString("novopen_settingEnabled", tableName: filename, bundle: Bundle.main, value: "NovoPen NFC scanning (experimental)", comment: "Settings toggle that turns on scanning a NovoPen over NFC. Experimental feature.")
    }()

    static let settingIgnoreAirShots: String = {
        return NSLocalizedString("novopen_settingIgnoreAirShots", tableName: filename, bundle: Bundle.main, value: "Ignore air shots", comment: "Settings toggle: do not save a small dose that is followed shortly by another dose, which is an air shot.")
    }()

    static let airShotFooter: String = {
        return NSLocalizedString("novopen_airShotFooter", tableName: filename, bundle: Bundle.main, value: "With Ignore air shots on, a dose of at most the max units that is followed within the window by another dose is not saved. Only the first small dose in each window is ignored. The newest small dose is held back until its window has passed: scan again a few minutes later to import it.", comment: "Settings footer explaining the air shot filter.")
    }()

    static let settingAirShotMaxUnits: String = {
        return NSLocalizedString("novopen_settingAirShotMaxUnits", tableName: filename, bundle: Bundle.main, value: "Air shot max units", comment: "Settings row: the largest dose that can be an air shot.")
    }()

    static let settingAirShotWindow: String = {
        return NSLocalizedString("novopen_settingAirShotWindow", tableName: filename, bundle: Bundle.main, value: "Air shot window", comment: "Settings row: how soon after an air shot the next dose must follow.")
    }()

    static let minutes: String = {
        return NSLocalizedString("novopen_minutes", tableName: filename, bundle: Bundle.main, value: "%d min", comment: "Value of the air shot window setting; %d is a number of minutes.")
    }()

    static let pen: String = {
        return NSLocalizedString("novopen_pen", tableName: filename, bundle: Bundle.main, value: "Pen %@", comment: "Settings row title for a known NovoPen; %@ is its serial number.")
    }()

    static let penKindBolus: String = {
        return NSLocalizedString("novopen_penKindBolus", tableName: filename, bundle: Bundle.main, value: "Bolus", comment: "Menu item: this pen holds rapid-acting (bolus) insulin.")
    }()

    static let scanResultTitle: String = {
        return NSLocalizedString("novopen_scanResultTitle", tableName: filename, bundle: Bundle.main, value: "NovoPen", comment: "Title of the alert that shows the result of a pen scan.")
    }()

    static let units: String = {
        return NSLocalizedString("novopen_units", tableName: filename, bundle: Bundle.main, value: "%d U", comment: "Value of the air shot max units setting; %d is a number of insulin units.")
    }()

    static let forgetPen: String = {
        return NSLocalizedString("novopen_forgetPen", tableName: filename, bundle: Bundle.main, value: "Forget", comment: "Menu item: forget this pen; it has to be added again before its doses are read.")
    }()
}
