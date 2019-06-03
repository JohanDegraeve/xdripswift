import Foundation

/// holds a path and query Items
///
/// kind of helpful class which handles the composing of a url for a url with query parameters
struct Endpoint {
    
    /// the host example www.mywebsite.com, exclusive http or https
    let host:String
    
    /// scheme to use, like http:// or https://
    let scheme:EndPointScheme

    /// the path yes
    let path: String
    
    /// array of URLQueryItem
    let queryItems: [URLQueryItem]
    
    /// gets url
    var url: URL? {
        var components = URLComponents()
        components.scheme = scheme.rawValue
        components.host = host
        components.path = path
        components.queryItems = queryItems
        
        return components.url
    }
}

/// enums for http, https, ...
enum EndPointScheme:String, CaseIterable {
    
    /// https://, rawvalue includes ://
    case https = "https"
    
    /// http://, rawvalue includes ://
    case http = "http"
    
    /// takes a hostname inclusive scheme as input, returns the host and scheme splitted
    ///
    /// example, hostAndScheme = https://www.example.com then returnvalue is www.example.com and EndPointScheme.https
    /// Note that EndPointScheme.https rawValue is 'https' and not 'https://'
    ///
    /// if hostAndScheme doesn't start with one of the cases in EndPointScheme, then returns (hostAndScheme, nil)
    static func getHostAndScheme(hostAndScheme:String) -> (String, EndPointScheme?) {
        
        for scheme in EndPointScheme.allCases {
            
            if hostAndScheme.lowercased().startsWith(scheme.rawValue) {
                
                // remove the scheme from hostAndScheme and replace : by empty string
                var shortnedHost = hostAndScheme[scheme.rawValue.count..<hostAndScheme.count]
                
                // if hostname starts with : remove the :
                if shortnedHost.startsWith(":") {
                    shortnedHost = shortnedHost[1..<shortnedHost.count]
                }
                
                // if hostname starts with // remove the //
                if shortnedHost.startsWith("//") {
                    shortnedHost = shortnedHost[2..<shortnedHost.count]
                }
                
                return (shortnedHost, scheme)
            }
        }
        
        return (hostAndScheme, nil)
    }
}

