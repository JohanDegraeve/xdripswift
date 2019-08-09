////
////  SwiftOOPWebExtensions.swift
////  SwitftOOPWeb
////
////  Created by Bjørn Inge Berg on 08.04.2018.
////  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
////
//import Foundation
//
//extension NSMutableURLRequest {
//
//    /// Populate the HTTPBody of `application/x-www-form-urlencoded` request
//    ///
//    /// :param: contentMap A dictionary of keys and values to be added to the request
//
//    func setBodyContent(contentMap: [String : String]) {
//        let parameters = contentMap.map { (key, value) -> String in
//            return "\(key)=\(value.stringByAddingPercentEscapesForQueryValue()!)"
//        }
//
//        httpBody =  parameters.joined(separator: "&").data(using: .utf8)
//    }
//}
//
//extension String {
//
//    /// Percent escape value to be added to a URL query value as specified in RFC 3986
//    ///
//    /// This percent-escapes all characters except the alphanumeric character set and "-", ".", "_", and "~".
//    ///
//    /// http://www.ietf.org/rfc/rfc3986.txt
//    ///
//    /// :returns: Return precent escaped string.
//
//    func stringByAddingPercentEscapesForQueryValue() -> String? {
//        let characterSet = NSMutableCharacterSet.alphanumeric()
//        characterSet.addCharacters(in: "-._~")
//        return self.addingPercentEncoding(withAllowedCharacters: characterSet as CharacterSet)
//    }
//}


//
//  SwiftOOPWebExtensions.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 08.04.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//
import Foundation

extension NSMutableURLRequest {
    
    /// Populate the HTTPBody of `application/x-www-form-urlencoded` request
    ///
    /// :param: contentMap A dictionary of keys and values to be added to the request
    
    func setBodyContent(contentMap: [String: String]) {
        let parameters = contentMap.map { (key, value) -> String in
            return "\(key)=\(value.stringByAddingPercentEscapesForQueryValue()!)"
        }
        
        httpBody =  parameters.joined(separator: "&").data(using: .utf8)
    }
}

extension String {
    
    /// Percent escape value to be added to a URL query value as specified in RFC 3986
    ///
    /// This percent-escapes all characters except the alphanumeric character set and "-", ".", "_", and "~".
    ///
    /// http://www.ietf.org/rfc/rfc3986.txt
    ///
    /// :returns: Return precent escaped string.
    
    func stringByAddingPercentEscapesForQueryValue() -> String? {
        let characterSet = NSMutableCharacterSet.alphanumeric()
        characterSet.addCharacters(in: "-._~")
        return self.addingPercentEncoding(withAllowedCharacters: characterSet as CharacterSet)
    }
    
    //: ### Base64 encoding a string
    func base64Encoded() -> String? {
        if let data = self.data(using: .utf8) {
            return data.base64EncodedString()
        }
        return nil
    }
    
    //: ### Base64 decoding a string
    func base64Decoded() -> [UInt8]? {
        if let data = Data(base64Encoded: self) {
            return [UInt8](data)
        }
        return nil
    }
}

extension Date {
    static func ISOStringFromDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
        return dateFormatter.string(from: date).appending("Z")
    }
    
    static func dateFromISOString(string: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        return dateFormatter.date(from: string)
    }
}
