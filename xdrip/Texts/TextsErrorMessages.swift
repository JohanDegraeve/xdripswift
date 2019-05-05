import Foundation

/// all texts for Error Messages related texts
enum Texts_ErrorMessages {
    static private let errorMessagesFileName = "ErrorMessages"
    
    static let DexcomTransmitterIDInvalidCharacters:String = {
        return NSLocalizedString("error_message_Dexcom_transmitter_id_invalid_characters", tableName: errorMessagesFileName, bundle: Bundle.main, value: "Transmitter id should only have characters a-z, A-Z, 0-9", comment: "transmitter id given by user has invalid characters, allowed characters are a-z, A-Z, 0-9")
    }()
    
    static let TransmitterIDShouldHaveLength6:String = {
        return NSLocalizedString("error_message_transmitter_id_should_have_length_6", tableName: errorMessagesFileName, bundle: Bundle.main, value: "Transmitter id should have length 6", comment: "error message for the case where Dexcom G5 transmitter id given by user doesn't have 6 characters")
    }()
    
    static let TransmitterIDShouldHaveLength5:String = {
        return NSLocalizedString("error_message_transmitter_id_should_have_length_5", tableName: errorMessagesFileName, bundle: Bundle.main, value: "Transmitter id should have length 5", comment: "error message for the case where Dexcom G5 transmitter id given by user doesn't have 5 characters")
    }()
}


