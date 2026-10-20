//
//  Libre3AccountLookup.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// One-time identity lookup only. Never downloads glucose or modifies follower settings.
/// Passwords and returned bearer tokens are not persisted or logged.
final class Libre3AccountLookup: NSObject, URLSessionTaskDelegate {
    enum LookupError: LocalizedError {
        case credentials, consent, unsupported
        var errorDescription: String? {
            switch self {
            case .credentials: return TextsLibre3.localized("The account login was not accepted.")
            case .consent: return TextsLibre3.localized("Open the official app to review its account terms, then retry.")
            case .unsupported: return TextsLibre3.localized("Account lookup is unavailable. Enter the original Account ID or Receiver ID manually.")
            }
        }
    }
    func accountID(email: String, password: String) async throws -> String {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let regions: Set<String> = ["ae", "ap", "au", "ca", "de", "eu", "eu2", "fr", "jp", "la", "us"]
        var host = "api.libreview.io"
        var visited = Set<String>()
        for _ in 0..<3 {
            guard visited.insert(host).inserted,
                  let url = URL(string: "https://\(host)/llu/auth/login") else { throw LookupError.unsupported }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("llu.ios", forHTTPHeaderField: "product")
            request.setValue(ConstantsLibreLinkUp.libreLinkUpVersionDefault, forHTTPHeaderField: "version")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int else { throw LookupError.unsupported }
            if status == 2 { throw LookupError.credentials }
            if status == 4 { throw LookupError.consent }
            guard status == 0, let payload = json["data"] as? [String: Any] else { throw LookupError.unsupported }
            if payload["redirect"] as? Bool == true {
                guard let region = payload["region"] as? String, regions.contains(region) else { throw LookupError.unsupported }
                host = "api-\(region).libreview.io"
                continue
            }
            guard let user = payload["user"] as? [String: Any], let id = user["id"] as? String,
                  UUID(uuidString: id) != nil else { throw LookupError.unsupported }
            return id.lowercased()
        }
        throw LookupError.unsupported
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Credentials must never follow arbitrary HTTP redirects.
        completionHandler(nil)
    }
}
