import Foundation

public class NightScoutManager {
    
    // MARK: - properties
    
    /// for readings and calibrations
    private let nightScoutEntriesPath = "/api/v1/entries"
    
    /// for treatments
    private let nightScoutTreatmentPath = "/api/v1/treatments"
    
    /// for devicestatus
    private let nightScoutDeviceStatusPath = "/api/v1/devicestatus"
    
    /// to test API Secret
    private let nightScoutAuthTestPath = "/api/v1/experiments/test"
    
    /// nightscout url
    private let siteURL:String
    /// nightscout api secret
    private let apiSecret:String
    
    init(siteURL:String, apiSecret:String) {
        self.siteURL = siteURL
        self.apiSecret = apiSecret
    }
}
