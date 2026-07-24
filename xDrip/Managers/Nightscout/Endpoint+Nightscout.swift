import Foundation


extension Endpoint {
    
    /// get Endpoint to fetch latest Nightscout entries
    ///
    /// The function takes host and scheme in one string, assuming it starts with a valid scheme name. The caller is supposed to have validated this.
    /// - parameters:
    ///     - hostAndScheme : hostname, eg http://www.mysite.com or https://www.mysite.com - must include the scheme - IF HOST DOESN'T START WITH A KNOWN SCHEME, THEN A FATAL ERROR WILL BE THROWN - known scheme's can be found in type EndPointScheme
    ///     - count : maximum number of readings to get
    ///     - minimumTimeStamp : only return readings at or after this timestamp
    ///     - token: the Nightscout token used for authentication (optional)
    ///     - port: Nightscout server port number (optional)
    static func getEndpointForLatestNSEntries(hostAndScheme:String, count: Int, minimumTimeStamp: Date, token: String?) -> Endpoint {
        
        // split hostAndScheme in host and scheme
        let (host, scheme) = EndPointScheme.getHostAndScheme(hostAndScheme: hostAndScheme)
        
        // if scheme nil then looks like a coding error, throw fatal error
        // before throwing the error, let's reset the Nightscout URL or it will not be possible to recover without deleting the app to remove coredata and re-installing
        guard scheme != nil else {
            UserDefaults.standard.nightscoutUrl = nil
            fatalError("in getEndpointForLatestNSEntries, hostAndScheme doesn't start with a known scheme name")
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
            scheme: scheme!,
            path: "/api/v1/entries/sgv.json",
            queryItems: queryItems,
            port: UserDefaults.standard.nightscoutPort
        )
    }
}
