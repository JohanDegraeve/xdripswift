/// constants typically for master mode
enum ConstantsMaster {
    
    /// maximum age in seconds, of reading in alert flow. If age of latest reading is more than this number, then no alert check will be done
    static let maximumBgReadingAgeForAlertsInSeconds = 240.0
    
    // minimum sensor warm-up time required for all transmitters/sensors before allowing the app to process a BG reading
    // this will only be relevant for active sensors that hold a sensorAge value

    /// warm-up time considered for all sensors/transmitters after starting (enforced globally by the app)
    static let minimumSensorWarmUpRequiredInMinutes = 45.0
    
    /// warm-up time enfoced by the Dexcom G6 transmitter. In this case, this will actually only be used for the UI to show when the sensor is reading.
    static let minimumSensorWarmUpRequiredInMinutesDexcomG5G6 = 120.0
    
}
