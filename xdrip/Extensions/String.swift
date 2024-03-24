import UIKit
import CryptoSwift

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
    
    /// validates if string matches regex
    func validate(withRegex regex: NSRegularExpression) -> Bool {
        let range = NSRange(self.startIndex..., in: self)
        let matchRange = regex.rangeOfFirstMatch(in: self, options: .reportProgress, range: range)
        return matchRange.location != NSNotFound
    }
    
    func startsWith(_ prefix: String) -> Bool {
        return lowercased().hasPrefix(prefix.lowercased())
    }
    
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
    
    func contains(find: String) -> Bool{
        return self.range(of: find) != nil
    }
    func containsIgnoringCase(find: String) -> Bool{
        return self.range(of: find, options: .caseInsensitive) != nil
    }
    
    func sha1() -> String {
        // sha1() here is a function in CryptoSwift Library
        return Data(self.utf8).sha1().hexEncodedString()
    }
    
    /// creates uicolor interpreting hex as hex color code, example #CED430
    func hexStringToUIColor () -> UIColor {
        var cString:String = self.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    /// checks if string length is > 0 and if so returns self, otherwise returns nil
    ///
    /// useful for instance to verify textfield input, if user lenters string of length 0, then better set it to nil
    func toNilIfLength0() -> String? {
        if self.count > 0 {return self}
        return nil
    }
    
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
    
    /// used for strings that represent a schedule
    /// - Example :
    /// - string = 5-480-660-1080
    /// - between 00:00  and 00:04, the value is on, between 00:05 and 07:59  on, ...
    func indicatesOn(forWhen when: Date) -> Bool {
        
        // minutes since midnight, for when
        let minutes = Int16(when.minutesSinceMidNightLocalTime())
        
        // start with true
        var isOn = true
        
        // split by "-" into array of int
        let schedule = self.split(separator: "-").map({Int($0) ?? 0})
        
        // loop through ints in the array, each time swap isOn, until entry > current minutes
        for entry in schedule {
            if entry > minutes {
                break
            }
            isOn = !isOn
        }
        
        return isOn
        
    }
    
    /// used for strings that represent a schedule
    /// - Example :
    /// - string = 5-480-660-1080
    /// - will return  [5, 480, 660, 1080]
    func splitToInt() -> [Int] {
        
        var schedule = [Int]()
        
        schedule = self.split(separator: "-").map({Int($0) ?? 0})
        
        return schedule
        
    }
    
    /// creates Data using String in hex format, same result as Data(hexadecimalString: String)
    func hexadecimal() -> Data? {
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
    
    func dateFromISOString() -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        return dateFormatter.date(from: self)
    }
    
    mutating func appendStringAndNewLine(_ stringToAdd: String) {
        
        self = self + stringToAdd + "\n"
        
    }
    
    /// use this to partially obscure a password, API-SECRET, token or other sensitive data. We want the user to see that something recognisable is there that makes sense to them, but it won't reveal any useful private information if they screenshot it
    func obscured() -> String {
        
        var obscuredString = self
        
        let stringLength: Int = obscuredString.count
        
        // in order to avoid strange layouts if somebody uses a really long API_SECRET or token, then let's limit the displayed string size to something more manageable
        let maxStringSizeToShow: Int = 12
        
        // the characters we will use to obscure the sensitive data
        let maskingCharacter: String = "*"
        
        // based upon the length of the string, we will show more, or less, of the original characters at the beginning. This gives more context whilst maintaining privacy
        var startCharsNotToObscure: Int = 0
        
        switch stringLength {
        case 0...3:
            startCharsNotToObscure = 0
        case 4...5:
            startCharsNotToObscure = 1
        case 6...7:
            startCharsNotToObscure = 2
        case 8...10:
            startCharsNotToObscure = 3
        case 11...50:
            startCharsNotToObscure = 4
        default:
            startCharsNotToObscure = 0
        }
        
        // remove the characters that we want to obscure
        obscuredString.removeLast(stringLength - startCharsNotToObscure)
        
        // now "fill up" the string with the masking character up to the original string size. If it is longer than the maxStingSizeToShow then trim it down to make everything fit in a clean way
        obscuredString += String(repeating: maskingCharacter, count: stringLength > maxStringSizeToShow ? maxStringSizeToShow - obscuredString.count : stringLength - obscuredString.count)
        
        return obscuredString
        
    }
    
}

extension Optional where Wrapped == String {
    
    /// - if string doesn't start with http, then add https
    /// - if ending with /, remove it
    /// - convert to lowercase
    /// - if string nil, then returnvalue is nil
    func addHttpsIfNeeded() -> String? {
        
        // if self nil, then return nil
        guard var returnValue = self else {return nil}
        
        // if self doesn't start with http or https, then add https. This might not make sense, but it will guard against throwing fatal errors when trying to get the scheme of the Endpoint
        if !returnValue.startsWith("http://") && !returnValue.startsWith("https://") {
            returnValue = "https://" + returnValue
        }
        
        // if url ends with /, remove it
        if returnValue.last == "/" {
            returnValue.removeLast()
        }
        
        return returnValue
        
    }
}
