import UIKit
import CommonCrypto

extension String {
    //https://stackoverflow.com/questions/39677330/how-does-string-substring-work-in-swift
    //usage
    //let s = "hello"
    //s[0..<3] // "hel"
    //s[3..<s.count] // "lo"
    subscript(_ range: CountableRange<Int>) -> String {
        let idx1 = index(startIndex, offsetBy: max(0, range.lowerBound))
        let idx2 = index(startIndex, offsetBy: min(self.count, range.upperBound))
        return String(self[idx1..<idx2])
    }
}

extension String {
    /// validates if string matches regex
    func validate(withRegex regex: NSRegularExpression) -> Bool {
        let range = NSRange(self.startIndex..., in: self)
        let matchRange = regex.rangeOfFirstMatch(in: self, options: .reportProgress, range: range)
        return matchRange.location != NSNotFound
    }
}

extension String {
    func startsWith(_ prefix: String) -> Bool {
        return lowercased().hasPrefix(prefix.lowercased())
    }
}

extension String {
    /// converts String to Double, works with decimal seperator . or , - if conversion fails then returns nil
    func toDouble() -> Double? {
        
        // if string is empty then no further processing needed, return nil
        if self.count == 0 {
            return nil
        }
        
        let returnValue:Double? = Double(self)
        if let returnValue = returnValue  {
            // Double value is correctly created, return it
            return returnValue
        } else {
            // first check if it has ',', replace by '.' and try again
            // else replace '.' by ',' and try again
            if self.indexes(of: ",").count > 0 {
                let newString = self.replacingOccurrences(of: ",", with: ".")
                return Double(newString)
            } else if self.indexes(of: ".").count > 0 {
                let newString = self.replacingOccurrences(of: ".", with: ",")
                return Double(newString)
            }
        }
        return nil
    }
}

extension String {
    func contains(find: String) -> Bool{
        return self.range(of: find) != nil
    }
    func containsIgnoringCase(find: String) -> Bool{
        return self.range(of: find, options: .caseInsensitive) != nil
    }
}

extension String {
    func sha1() -> String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
    
    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
}

extension String {
    /// creates uicolor interpreting hex as hex color code, example #CED430
    func hexStringToUIColor () -> UIColor {
        var cString:String = self.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

}

extension String {
    
    /// checks if string length is > 0 and if so returns self, otherwise returns nil
    ///
    /// useful for instance to verify textfield input, if user lenters string of length 0, then better set it to nil
    func toNilIfLength0() -> String? {
        if self.count > 0 {return self}
        return nil
    }
}

extension String {
    
    /// Percent escape value to be added to a URL query value as specified in RFC 3986
    ///
    /// This percent-escapes all characters except the alphanumeric character set and "-", ".", "_", and "~".
    ///
    /// http://www.ietf.org/rfc/rfc3986.txt
    ///
    /// - returns: Return precent escaped string.
    func stringByAddingPercentEscapesForQueryValue() -> String? {
        let characterSet = NSMutableCharacterSet.alphanumeric()
        characterSet.addCharacters(in: "-._~")
        return self.addingPercentEncoding(withAllowedCharacters: characterSet as CharacterSet)
    }
    
    /// Base64 encoding a string
    func base64Encoded() -> String? {
        if let data = self.data(using: .utf8) {
            return data.base64EncodedString()
        }
        return nil
    }
    
    /// Base64 decoding a string
    func base64Decoded() -> [UInt8]? {
        if let data = Data(base64Encoded: self) {
            return [UInt8](data)
        }
        return nil
    }
}

extension String {
    func dateFromISOString() -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        return dateFormatter.date(from: self)
    }
}
