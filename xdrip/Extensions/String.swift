import Foundation

//https://stackoverflow.com/questions/39677330/how-does-string-substring-work-in-swift
//usage
//let s = "hello"
//s[0..<3] // "hel"
//s[3..<s.count] // "lo"
extension String {
    subscript(_ range: CountableRange<Int>) -> String {
        let idx1 = index(startIndex, offsetBy: max(0, range.lowerBound))
        let idx2 = index(startIndex, offsetBy: min(self.count, range.upperBound))
        return String(self[idx1..<idx2])
    }
}

/// validates if string matches regex
extension String {
    func validate(withRegex regex: NSRegularExpression) -> Bool {
        let range = NSRange(self.startIndex..., in: self)
        let matchRange = regex.rangeOfFirstMatch(in: self, options: .reportProgress, range: range)
        return matchRange.location != NSNotFound
    }
}
