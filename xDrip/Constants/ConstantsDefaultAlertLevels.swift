/// default alert levels to be used when creating defalt alert entries
enum ConstantsDefaultAlertLevels {
    // default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
    static let defaultBatteryAlertLevelDexcomG5 = 270
    // G7, ONE+ and Stelo use a much lower disposable-sensor Voltage B range than G5/G6/ONE.
    // Keep this equal to the `.g7` red boundary so the battery symbol and default alarm agree.
    static let defaultBatteryAlertLevelDexcomG7 = 215
    static let defaultBatteryAlertLevelMiaoMiao = 20
    static let defaultBatteryAlertLevelBubble = 20
    static let defaultBatteryAlertLevelLibre2 = 20
    static let defaultBatteryAlertLevelPhone = 10
    
    // blood glucose level alert values in mgdl
    static let veryHigh = 250
    static let veryLow = 50
    static let high = 170
    static let low = 70
    
    // blood glucose fast drop delta alert in mgdl
    static let fastdrop = 10
    static let fastdropTriggerValue = 120

    // blood glucose fast rise delta alert in mgdl
    static let fastrise = 10
    static let fastriseTriggerValue = 160
    
    // in minutes, after how many minutes of now reading should alert be raised
    static let missedReading = 30

    // in minutes, after how many minutes without a loop cycle should an alert be raised
    static let notLooping = 30
    
    // in hours, after how many hours alert to request a new calibration
    static let calibration = 24
}
