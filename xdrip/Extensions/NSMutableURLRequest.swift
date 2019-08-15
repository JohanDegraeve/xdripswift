import Foundation

extension NSMutableURLRequest {
    
    /// Populate the HTTPBody of `application/x-www-form-urlencoded` request
    ///
    /// - parameters:
    ///     - contentMap : A dictionary of keys and values to be added to the request
    func setBodyContent(contentMap: [String: String]) {
        let parameters = contentMap.map { (key, value) -> String in
            return "\(key)=\(value.stringByAddingPercentEscapesForQueryValue()!)"
        }
        
        httpBody =  parameters.joined(separator: "&").data(using: .utf8)
    }
}
