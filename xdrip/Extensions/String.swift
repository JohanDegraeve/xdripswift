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
