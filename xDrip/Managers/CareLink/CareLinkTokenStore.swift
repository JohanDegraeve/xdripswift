//
//  CareLinkTokenStore.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import Security

/// Minimal credential-store boundary used by production Keychain code and deterministic tests.
/// Implementations must never place session values in UserDefaults, backups or diagnostics.
protocol CareLinkTokenStoring: AnyObject {
    func load() throws -> CareLinkToken?
    func save(_ token: CareLinkToken) throws
    func clear() throws
}

/// Stores the complete CareLink web-session credential as one generic-password Keychain value.
final class CareLinkKeychainTokenStore: CareLinkTokenStoring {
    private let service: String
    private let legacyService: String?
    private let account = "personal-web-session"
    private let obsoleteAccount = "oauth-token"

    convenience init() {
        self.init(
            // Use the app's established name constant so alternate bundle configurations do not
            // create separate CareLink identities in Keychain.
            service: ConstantsHomeView.applicationName + ".carelink"
        )
    }

    /// Injectable service names isolate Keychain unit tests from the production item.
    init(service: String, legacyService: String? = nil) {
        self.service = service
        self.legacyService = legacyService == service ? nil : legacyService
    }

    /// Loads the canonical item and discards the incompatible OAuth beta item.
    func load() throws -> CareLinkToken? {
        if let token = try load(service: service) { return token }
        try delete(service: service, account: obsoleteAccount)
        if let legacyService { try delete(service: legacyService, account: obsoleteAccount) }
        return nil
    }

    /// Reads and decodes one exact generic-password item.
    private func load(service: String) throws -> CareLinkToken? {
        var query = baseQuery(service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status) }
        return try JSONDecoder().decode(CareLinkToken.self, from: data)
    }

    /// Upserts an after-first-unlock, this-device-only item suitable for background polling.
    func save(_ token: CareLinkToken) throws {
        let data = try JSONEncoder().encode(token)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let query = baseQuery(service: service)
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status)
        }
    }

    /// Deletes canonical and legacy items so explicit logout cannot leave usable credentials.
    func clear() throws {
        try delete(service: service)
        try delete(service: service, account: obsoleteAccount)
        if let legacyService {
            try delete(service: legacyService)
            try delete(service: legacyService, account: obsoleteAccount)
        }
    }

    /// Treats an already absent item as successful idempotent deletion.
    private func delete(service: String, account: String? = nil) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status) }
    }

    /// Explicitly disables iCloud Keychain synchronization so tokens cannot leave this device.
    private func baseQuery(service: String, account: String? = nil) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account ?? self.account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    private struct KeychainError: LocalizedError {
        let status: OSStatus
        init(_ status: OSStatus) { self.status = status }
        var errorDescription: String? { SecCopyErrorMessageString(status, nil) as String? }
    }
}

/// Non-persistent test double used to exercise rotation and concurrency without Keychain state.
final class CareLinkMemoryTokenStore: CareLinkTokenStoring {
    var token: CareLinkToken?
    func load() throws -> CareLinkToken? { token }
    func save(_ token: CareLinkToken) throws { self.token = token }
    func clear() throws { token = nil }
}
