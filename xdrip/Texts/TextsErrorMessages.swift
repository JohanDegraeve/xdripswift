import Foundation

/// all texts for Error Messages related texts
enum Texts_ErrorMessages {
    static private let errorMessagesFileName = "ErrorMessages"
    
    static let DexcomTransmitterIDInvalidCharacters:String = {
        return NSLocalizedString("error_message_Dexcom_transmitter_id_invalid_characters", tableName: errorMessagesFileName, bundle: Bundle.main, value: "The Transmitter ID should only contain characters a-z, A-Z or 0-9", comment: "transmitter id given by user has invalid characters, allowed characters are a-z, A-Z, 0-9")
    }()
    
    static let DexcomG7TypeTransmitterIDWrongPattern:String = {
        return NSLocalizedString("error_message_DexcomG7TypeTransmitterIDWrongPattern", tableName: errorMessagesFileName, bundle: Bundle.main, value: "The Transmitter ID should start with DX", comment: "transmitter id given by user doesn't start with DX")
    }()
    
    static let TransmitterIDShouldHaveLength6:String = {
        return NSLocalizedString("error_message_transmitter_id_should_have_length_6", tableName: errorMessagesFileName, bundle: Bundle.main, value: "The Transmitter ID should be 6 characters long", comment: "error message for the case where Dexcom G5 transmitter id given by user doesn't have 6 characters")
    }()
    
    static let TransmitterIDShouldHaveMaximumLength6:String = {
        return NSLocalizedString("error_message_transmitter_id_should_have_maximum_length_6", tableName: errorMessagesFileName, bundle: Bundle.main, value: "The Transmitter ID should be maximum 6 characters long", comment: "error message for the case where Dexcom G7 transmitter id given by user has more than 6 characters")
    }()
    
    static let TransmitterIDShouldHaveLength5:String = {
        return NSLocalizedString("error_message_transmitter_id_should_have_length_5", tableName: errorMessagesFileName, bundle: Bundle.main, value: "The Transmitter ID should be 5 characters long", comment: "error message for the case where Dexcom G5 transmitter id given by user doesn't have 5 characters")
    }()
    
    static let DexcomG7TransmitterShouldStartWithDX:String = {
        return NSLocalizedString("error_message_DexcomG7TransmitterShouldStartWithDX", tableName: errorMessagesFileName, bundle: Bundle.main, value: "A Dexcom G7/ONE+/Stelo transmitter ID must start with 'DX'", comment: "transmitter id given by user does not start with DX")
    }()
}


