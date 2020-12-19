/// constants for Dexcom Share
enum ConstantsDexcomShare {
    
    /// applicationId to use in Dexcom Share protocol
    static let applicationId = "d8665ade-9673-4e27-9ff6-92db4ce13d13"
    
    /// us share base url
    static let usBaseShareUrl = "https://share2.dexcom.com/ShareWebServices/Services"
    
    /// non us share base url
    static let nonUsBaseShareUrl = "https://shareous1.dexcom.com/ShareWebServices/Services"
    
    /// if the time between the last and last but one reading is less than minimiumTimeBetweenTwoReadingsInMinutes, then the last reading will not be uploaded - except if there's been a disconnect in between these two readings
    static let minimiumTimeBetweenTwoReadingsInMinutes = 4.75

}


