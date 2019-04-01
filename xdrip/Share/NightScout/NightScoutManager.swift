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
    private var siteURL:String?
    /// nightscout api secret
    private var apiSecret:String?
    /// BgReadings instance
    private let bgReadings:BgReadings
    
    init(bgReadings:BgReadings) {
        
        self.bgReadings = bgReadings
        
    }
    
    /// synchronizes all NightScout related, if needed
    public func synchronize() {
        
        // check if NightScout upload is enabled
        if UserDefaults.standard.uploadReadingsToNightScout {
            uploadBgReadingsToNightScout()
        }
        
    }
    
    private func uploadBgReadingsToNightScout() {
        
    }
}
