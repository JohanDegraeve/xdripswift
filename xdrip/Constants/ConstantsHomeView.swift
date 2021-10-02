/// constants for home view, ie first view
enum ConstantsHomeView {
    
    /// how often to update the labels in the homeview (ie label with latest reading, minutes ago, etc..)
    static let updateHomeViewIntervalInSeconds = 15.0
    
    /// info email adres, appears in licenseInfo
    static let infoEmailAddress = "xdrip@proximus.be"
    
    /// application name, appears in licenseInfo as title
    static let applicationName = "xDrip4iO5"
    
    /// URL where the online help should be loaded from
    static let onlineHelpURL = "https://xdrip4ios.readthedocs.io"
    
    /// example URL to show the online help in Spanish using Google Translate
    /// https://xdrip4ios-readthedocs-io.translate.goog/en/latest/?_x_tr_sl=auto&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=nui
    /// we'll use this to spilt into two separate strings
    static let onlineHelpURLTranslated1 = "https://xdrip4ios-readthedocs-io.translate.goog/en/latest/?_x_tr_sl=auto&_x_tr_tl="
    static let onlineHelpURLTranslated2 = "&_x_tr_hl=es&_x_tr_pto=nui"
}
