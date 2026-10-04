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
        // Family-specific identifiers prevent one Dexcom family's notification from replacing the
        // other while collectors are being changed or saved alert state is being restored.
        static let dexcomG5BatteryLow = "dexcomG5BatteryLow"
        static let dexcomG7BatteryLow = "dexcomG7BatteryLow"
        /// fast drop
        static let fastDropAlert = "fastDropAlert"
        /// fast rise
        static let fastRiseAlert = "fastRiseAlert"
        /// phone battery low
        static let phoneBatteryLow = "phoneBatteryLow"
        /// not looping
        static let notLoopingAlert = "notLoopingAlert"
        /// manufacturer-reported terminal sensor or transmitter failure
        static let sensorTransmitterFailure = "sensorTransmitterFailure"
    }
    
    /// identifiers for calibration requests
    enum NotificationIdentifiersForCalibration {
        /// for initial calibration
        static let initialCalibrationRequest = "initialCalibrationRequest"
        static let dexcomG6InitialCalibrationRequest = "dexcomG6InitialCalibrationRequest"
        /// subsequent calibration request
        static let subsequentCalibrationRequest = "subsequentCalibrationRequest"
    }
    
    enum NotificationIdentifierForBgReading {
        /// bgreading notification
        static let bgReadingNotificationRequest = "bgReadingNotificationRequest"
    }
    
    enum NotificationIdentifierForBgPostProcessing {
        /// bg post processing update notification
        static let bgPostProcessingDidUpdate = "bgPostProcessingDidUpdate"
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
