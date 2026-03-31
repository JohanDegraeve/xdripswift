import Foundation
// source https://gist.github.com/bpolania/704901156020944d3e20fef515e73d61

extension UInt8 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt8>.size)
    }
}
