//
//  WebServicesManager.swift
//  xdrip
//
//  Created by Cloves Ferreira Jr on 06/01/20.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation
import Telegraph

public class WebServicesManager: NSObject {
    private var identity: CertificateIdentity?
    private var caCertificate: Certificate?
    private var tlsPolicy: TLSPolicy?
    
    private var dtFormatter : DateFormatter?
    
    var server: Server!
    var webSocketClient: WebSocketClient!
    
    var ipAddress = SystemInfoHelper.ipAddress()
}

public extension WebServicesManager {
    
    func start() {
        // Comment out this line if you want HTTP instead of HTTPS
        loadCertificates()
        
        // Create and start the server
        setupServer()
        
        // Demonstrate client requests and web socket connection
        //demoClientNormalRequest()
        //demoClientJSONRequest()
        //demoWebSocketConnect()
    }
    
    func stop() {
        server.stop()
    }
}

extension WebServicesManager {
    private func loadCertificates() {
        // Load the P12 identity package from the bundle
        if let identityURL = Bundle.main.url(forResource: "localhost", withExtension: "p12") {
            identity = CertificateIdentity(p12URL: identityURL, passphrase: "test")
        }
        
        // Load the Certificate Authority certificate from the bundle
        if let caCertificateURL = Bundle.main.url(forResource: "ca", withExtension: "der") {
            caCertificate = Certificate(derURL: caCertificateURL)
        }
        
        // We want to override the default SSL handshake. We aren't using a trusted root
        // certificate authority and the hostname doesn't match the common name of the certificate.
        if let caCertificate = caCertificate {
            tlsPolicy = TLSPolicy(commonName: "localhost", certificates: [caCertificate])
        }
    }
    
    private func setupServer() {
        // Create the server instance
        if let identity = identity, let caCertificate = caCertificate {
            server = Server(identity: identity, caCertificates: [caCertificate])
        } else {
            server = Server()
        }
        
        // Set the delegates and a low web socket ping interval to demonstrate ping-pong
        server.delegate = self
        server.webSocketDelegate = self
        server.webSocketConfig.pingInterval = 10
        

        server.route(.GET, "hello/:name", serverHandleHello)
        server.route(.GET, "hello(/)", serverHandleHello)
        server.route(.GET, "redirect", serverHandleRedirect)
        server.route(.GET, "secret/*") { .forbidden }
        server.route(.GET, "status") { (.ok, "Server is running") }
        server.route(.POST, "data", serverHandleData)

        // Define the Nightscout API v1 routes

        server.route(.POST, "entries", serverHandleEntries)
        server.route(.POST, "entries/current", serverHandleEntriesCurrent)
        server.route(.POST, "entries/status", serverHandleEntriesStatus)
        server.route(.POST, "devicestatus", serverHandleDeviceStatus)
        server.route(.POST, "entries/sgv", serverHandleEntriesSgv)
        server.route(.POST, "entries/treatments", serverHandleEntriesTreatments)
        server.route(.POST, "entries/profile", serverHandleEntriesProfile)
        server.route(.POST, "entries/profile/current", serverHandleEntriesProfileCurrent)
        server.route(.POST, "entries/cal", serverHandleEntriesCal)
        server.route(.POST, "pebble", serverHandlePebble)


        server.serveBundle(.main, "/")
        
        // Handle up to 10 requests simultaneously
        server.concurrency = 10
        
        // Start the server on localhost
        // Note: we'll skip error handling
        try! server.start(onPort: ConstantsWebServices.webServicesPort)
        
        // Log the url for easy access
        print("[SERVER]", "Server is running: \(serverURL())")
        print("[SERVER]", "Server is running:  \(serverURL(host:SystemInfoHelper.ipAddress()))")
    }
}

// MARK: - Server route handlers

extension WebServicesManager {

    /// Raised when the /entries.json endpoint is called.
    private func serverHandleEntries(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries.json not implemented yet.")
    }

    /// Raised when the /entries/current.json endpoint is called.
    private func serverHandleEntriesCurrent(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries/current.json not implemented yet.")
    }

    /// Raised when the /entries/status.json endpoint is called.
    private func serverHandleEntriesStatus(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries/status.json not implemented yet.")
    }

    /// Raised when the /devicestatus.json endpoint is called.
    private func serverHandleDeviceStatus(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/devicestatus.json not implemented yet.")
    }

    /// Raised when the /entries/sgv.json endpoint is called.
    private func serverHandleEntriesSgv(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries/sgv.json not implemented yet.")
    }

    /// Raised when the /entries/treatments.json endpoint is called.
    private func serverHandleEntriesTreatments(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries/treatments.json not implemented yet.")
    }
 
    /// Raised when the /entries/profile.json endpoint is called.
    private func serverHandleEntriesProfile(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries/profile.json not implemented yet.")
    }

    /// Raised when the /entries/profile/current.json endpoint is called.
    private func serverHandleEntriesProfileCurrent(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries/profile/current.json not implemented yet.")
    }

    /// Raised when the /entries/cal.json endpoint is called.
    private func serverHandleEntriesCal(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/entries/cal.json not implemented yet.")
    }

    /// Raised when the /pebble.json endpoint is called.
    private func serverHandlePebble(request: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(content: "/pebble.json not implemented yet.")
    }

  /// Raised when the /hello endpoint is called.
  private func serverHandleHello(request: HTTPRequest) -> HTTPResponse {
    let name = request.params["name"] ?? "stranger"
    return HTTPResponse(content: "Hello \(name.capitalized)")
  }

  /// Raised when the /redirect endpoint is called.
  private func serverHandleRedirect(request: HTTPRequest) -> HTTPResponse {
    let response = HTTPResponse(.temporaryRedirect)
    response.headers.location = "https://www.google.com"
    return response
  }

  /// Raised when the /data endpoint is called.
  private func serverHandleData(request: HTTPRequest) -> HTTPResponse {
    // Decode the request body using the JSON decoder, fallback to "stranger" if the data is invalid
    let requestDict = try? JSONDecoder().decode([String: String].self, from: request.body)
    let name = requestDict?["name"] ?? "stranger"

    // Send a JSON response containing the name of our visitor
    let responseDict = ["welcome": name]
    let jsonData = try! JSONEncoder().encode(responseDict)
    return HTTPResponse(body: jsonData)
  }
}

// MARK: - ServerDelegate implementation

extension WebServicesManager: ServerDelegate {
  // Raised when the server gets disconnected.
  public func serverDidStop(_ server: Server, error: Error?) {
    print("[SERVER]", "Server stopped:", error?.localizedDescription ?? "no details")
  }
}

// MARK: - ServerWebSocketDelegate implementation

extension WebServicesManager: ServerWebSocketDelegate {
  /// Raised when a web socket client connects to the server.
  public func server(_ server: Server, webSocketDidConnect webSocket: WebSocket, handshake: HTTPRequest) {
    let name = handshake.headers["X-Name"] ?? "stranger"
    print("[SERVER]", "WebSocket connected - name:", name)

    webSocket.send(text: "Welcome client \(name)")
    webSocket.send(data: Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]))
  }

  /// Raised when a web socket client disconnects from the server.
  public func server(_ server: Server, webSocketDidDisconnect webSocket: WebSocket, error: Error?) {
    print("[SERVER]", "WebSocket disconnected:", error?.localizedDescription ?? "no details")
  }

  /// Raised when the server receives a web socket message.
  public func server(_ server: Server, webSocket: WebSocket, didReceiveMessage message: WebSocketMessage) {
    print("[SERVER]", "WebSocket message received:", message)
  }

  /// Raised when the server sends a web socket message.
  public func server(_ server: Server, webSocket: WebSocket, didSendMessage message: WebSocketMessage) {
    print("[SERVER]", "WebSocket message sent:", message)
  }
}

// MARK: - URLSessionDelegate implementation

extension WebServicesManager: URLSessionDelegate {
  public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    // Use our custom TLS policy to verify if the server should be trusted
    let credential = tlsPolicy!.evaluateSession(trust: challenge.protectionSpace.serverTrust)
    completionHandler(credential == nil ? .cancelAuthenticationChallenge : .useCredential, credential)
  }
}

// MARK: Request helpers

extension WebServicesManager {
    /// Performs a client request to our server.
    private func performClientRequest(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse) -> Void) {
        // Create a client session, we are setting ourself as the delegate to customize the SSL handshake
        let httpClient = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        
        // Create the request task, we'll centralize the request errors
        let httpTask = httpClient.dataTask(with: request) { data, response, error in
            if let error = error {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[CLIENT]", "Request failed - status:", statusCode, "- error:", error.localizedDescription)
            } else {
                completionHandler(data, response!)
            }
        }
        
        // Perform the request
        httpTask.resume()
    }
    
    /// Generates a server url, we'll assume the server has been started.
    private func serverURL(path: String = "", host: String = "127.0.0.1") -> URL {
        var components = URLComponents()
        components.scheme = server.isSecure ? "https" : "http"
        components.host = host
        components.port = Int(server.port)
        components.path = path
        return components.url!
    }
}

extension WebServicesManager {
  /// Demonstrates a GET request on the /hello endpoint.
  private func demoClientNormalRequest() {
    let request = URLRequest(url: serverURL(path: "/hello"))
    performClientRequest(with: request, completionHandler: self.clientHandleHello)
  }

  /// Demonstrates a POST request on the /data endpoint.
  private func demoClientJSONRequest() {
    var request = URLRequest(url: serverURL(path: "/data"))
    request.httpMethod = "POST"
    request.httpBody = try! JSONEncoder().encode(["name": "Yvo"])
    performClientRequest(with: request, completionHandler: self.clientHandleData)
  }

  /// Demonstrates a client websocket connection.
  private func demoWebSocketConnect() {
    // Create the web socket client instance
    if let caCertificate = caCertificate {
        webSocketClient = try! WebSocketClient(url: serverURL(), certificates: [caCertificate])
    } else {
        webSocketClient = try! WebSocketClient(url: serverURL())
    }

    // We can define our own protocal and set custom headers
    webSocketClient.headers.webSocketProtocol = "myProtocol"
    webSocketClient.headers["X-Name"] = "Yvo"

    // Open the web socket connection
    webSocketClient.delegate = self
    webSocketClient.connect()
  }
}

// MARK: - WebSocketClientDelegate implementation

extension WebServicesManager: WebSocketClientDelegate {
  /// Raised when the web socket client has connected to the server.
  public func webSocketClient(_ client: WebSocketClient, didConnectToHost host: String) {
    print("[CLIENT]", "WebSocket connected - host:", host)
  }

  /// Raised when the web socket client received data.
  public func webSocketClient(_ client: WebSocketClient, didReceiveData data: Data) {
    print("[CLIENT]", "WebSocket message received - data:", data as NSData)
  }

  /// Raised when the web socket client received text.
  public func webSocketClient(_ client: WebSocketClient, didReceiveText text: String) {
    print("[CLIENT]", "WebSocket message received - text:", text)
  }

  /// Raised when the web socket client disconnects. Provides an error if the disconnect was unexpected.
  public func webSocketClient(_ client: WebSocketClient, didDisconnectWithError error: Error?) {
    print("[CLIENT]", "WebSocket disconnected - error:", error?.localizedDescription ?? "no error")
  }
}

extension WebServicesManager {
  /// Raised when the client processes the /hello endpoint response.
  private func clientHandleHello(data: Data?, response: URLResponse) {
    if let textData = data, let text = String(data: textData, encoding: .utf8) {
      print("[CLIENT]", "Request on /hello succeeded - text:", text)
    }
  }

  /// Raised when the client processes the /data endpoint response.
  private func clientHandleData(data: Data?, response: URLResponse) {
    if let jsonData = data, let json = try? JSONDecoder().decode([String: String].self, from: jsonData) {
      print("[CLIENT]", "Request on /data succeded - json:", json)
    }
  }
}
