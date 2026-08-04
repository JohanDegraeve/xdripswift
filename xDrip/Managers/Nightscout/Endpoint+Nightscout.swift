import Foundation


extension Endpoint {
    
    /// get Endpoint to fetch latest Nightscout entries
    ///
    /// The function takes host and scheme in one string and returns nil if it does not start with a supported scheme.
    /// - parameters:
    ///     - hostAndScheme : hostname, eg http://www.mysite.com or https://www.mysite.com - must include the scheme
    ///     - count : maximum number of readings to get
    ///     - minimumTimeStamp : only return readings at or after this timestamp
    ///     - token: the Nightscout token used for authentication (optional)
    ///     - port: Nightscout server port number (optional)
    static func getEndpointForLatestNSEntries(hostAndScheme: String, count: Int, minimumTimeStamp: Date, token: String?) -> Endpoint? {
        
        // split hostAndScheme in host and scheme
        let (host, scheme) = EndPointScheme.getHostAndScheme(hostAndScheme: hostAndScheme)
        
        // a URL restored from an older or invalid backup can bypass the settings validation
        guard let scheme = scheme else {
            UserDefaults.standard.nightscoutUrl = nil
            return nil
        }
        
        // create queryItems
        // Nightscout API v1 supports find[date][$gte] for timestamp-bounded reads:
        // https://github.com/nightscout/cgm-remote-monitor/blob/master/docs/requirements/api-v1-compatibility-requirements.md#compat-002-query-parameters
        let minimumTimeStampInMilliseconds = Int64(minimumTimeStamp.timeIntervalSince1970 * 1000.0)
        var queryItems = [
            URLQueryItem(name: "count", value: count.description),
            URLQueryItem(name: "find[date][$gte]", value: minimumTimeStampInMilliseconds.description)
        ]
        
        // if token not nil, then add also the token
        if let token = token {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        
        return Endpoint(
            host: host,
            scheme: scheme,
            path: "/api/v1/entries/sgv.json",
            queryItems: queryItems,
            port: UserDefaults.standard.nightscoutPort
        )
    }
}
