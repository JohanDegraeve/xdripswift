enum ConstantsNotifications {
    
    /// identifiers for alert notifications
    enum NotificationIdentifiersForAlerts {
        /// high alert
        static let highAlert = "highAlert"
        /// low alert
        static let lowAlert = "lowAlert"
        /// very high alert
        static let veryHighAlert = "veryHighAlert"
        /// very low alert
        static let veryLowAlert = "veryLowAlert"
        /// missed reading alert
        static let missedReadingAlert = "missedReadingAlert"
        /// battery low
        static let batteryLow = "batteryLow"
        /// fast drop
        static let fastDropAlert = "fastDropAlert"
        /// fast rise
        static let fastRiseAlert = "fastRiseAlert"
        /// phone battery low
        static let phoneBatteryLow = "phoneBatteryLow"
    }
    
    /// identifiers for calibration requests
    enum NotificationIdentifiersForCalibration {
        /// for initial calibration
        static let initialCalibrationRequest = "initialCalibrationRequest"
        /// subsequent calibration request
        static let subsequentCalibrationRequest = "subsequentCalibrationRequest"
    }
    
    enum NotificationIdentifierForBgReading {
        /// bgreading notification
        static let bgReadingNotificationRequest = "bgReadingNotificationRequest"
    }
    
    enum NotificationIdentifierForSensorNotDetected {
        /// sensor not detected notification
        static let sensorNotDetected = "sensorNotDetected"
    }
    
    enum NotificationIdentifierForTransmitterNeedsPairing {
        /// transmitter needs pairing
        static let transmitterNeedsPairing = "transmitterNeedsPairing"
    }
    
    enum NotificationIdentifierForResetResult {
        /// transmitter reset result
        static let transmitterResetResult = "transmitterResetResult"
    }
    
    /// notification identifier for  volume test notification
    static let notificationIdentifierForVolumeTest = "notificationIdentifierForVolumeTest"
    
    /// notification identifier for xDripErrors received in RootViewController's cgmTransmitterDelegate
    static let notificationIdentifierForxCGMTransmitterDelegatexDripError = "notificationIdentifierForxCGMTransmitterDelegatexDripError"
    
}
