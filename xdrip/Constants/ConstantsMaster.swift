/// constants typically for master mode
enum ConstantsMaster {
    
    /// maximum age in seconds, of reading in alert flow. If age of latest reading is more than this number, then no alert check will be done
    static let maximumBgReadingAgeForAlertsInSeconds = 240.0
    
    /// minimum sensor warm-up time required for all sensors before allowing the app to process a BG reading
    /// this will only be relevant for active sensors that hold a sensorAge value
    /// some transmitters (such as Dexcom) enforce warm-up on the transmitter side before transmitting values
    static let minimumSensorWarmUpRequiredInMinutes = 45.0
    
}
