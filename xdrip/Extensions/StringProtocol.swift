import Foundation

//https://stackoverflow.com/questions/32305891/index-of-a-substring-in-a-string-with-swift/32306142
extension StringProtocol where Index == String.Index {
    ///can be used to split a string in array of strings, splitted by other string
    func indexes(of string: Self, options: String.CompareOptions = []) -> [Index] {
        var result: [Index] = []
        var start = startIndex
        while start < endIndex,
            let range = self[start..<endIndex].range(of: string, options: options) {
                result.append(range.lowerBound)
                start = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}
