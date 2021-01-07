import Foundation


extension Endpoint {
    
    /// get Endpoint to fetch latest NightScout entries
    ///
    /// The function takes host and scheme in one string, assuming it starts with a valid scheme name. The caller is supposed to have validated this.
    /// - parameters:
    ///     - hostAndScheme : hostname, eg http://www.mysite.com or https://www.mysite.com - must include the scheme - IF HOST DOESN'T START WITH A KNOWN SCHEME, THEN A FATAL ERROR WILL BE THROWN - known scheme's can be found in type EndPointScheme
    ///     - count : maximum number of readings to get
    ///     - olderThan : only readings with timestamp > olderThan
    static func getEndpointForLatestNSEntries(hostAndScheme:String, count: Int, olderThan timeStamp:Date, token: String?) -> Endpoint {
        
        // split hostAndScheme in host and scheme
        let (host, scheme) = EndPointScheme.getHostAndScheme(hostAndScheme: hostAndScheme)
        
        // if scheme nil then looks like a coding error, throw fatal error
        guard scheme != nil else {fatalError("in getEndpointForLatestNSEntries, hostAndScheme doesn't start with a known scheme name")}
        
        // create quertyItems
        var queryItems = [
            URLQueryItem(name: "count", value: count.description),
        URLQueryItem(name: "find[dateString][$gte]", value: timeStamp.ISOStringFromDate())]
        
        // if token not nil, then add also the token
        if let token = token {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        
        return Endpoint(
            host:host,
            scheme:scheme!,
            path: "/api/v1/entries/sgv.json",
            queryItems: queryItems
        )
    }
}
