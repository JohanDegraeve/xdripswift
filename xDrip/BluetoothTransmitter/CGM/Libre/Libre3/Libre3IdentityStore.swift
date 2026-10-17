//
//  Libre3IdentityStore.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CryptoKit

/// Versioned download metadata is compiled in, app certificates and private keys are not.
struct Libre3IdentitySource: Equatable, Sendable {
    let version: String
    let transaction: String
    let digest: String
    static let current = Libre3IdentitySource(
        version: "app-identities-1",
        transaction: "qWbA3dXIHU2sU51oYtdYlouSfkCx-GczN2swLQb0upk",
        digest: "ab18ce8bcb978526e102cc5e16440f06d2aee19426c26a15dd0013d66e9995ed")
    var gateways: [URL] {
        ["https://arweave.net/", "https://turbo-gateway.com/"].compactMap { URL(string: $0 + transaction) }
    }
}

struct Libre3IdentityVersion: Codable, Identifiable, Equatable {
    var id: String
    var downloadedAt: Date
    var digest: String
    var labels: [String]
}

/// Serialized provisioning prevents simultaneous setup/settings downloads from replacing each other.
/// The complete validated JSON is stored in device-only Keychain, never diagnostics or app backups.
actor Libre3IdentityStore {
    static let shared = Libre3IdentityStore()
    private let storage: Libre3CredentialStore
    private let defaults: UserDefaults
    private var download: Task<Libre3IdentityVersion, Error>?
    private let installationMarker = "libre3.identityInstallation"

    init(
        service: String = (Bundle.main.bundleIdentifier ?? "xdrip") + ".libre3.identities",
        defaults: UserDefaults = .standard
    ) {
        self.storage = Libre3CredentialStore(service: service)
        self.defaults = defaults
    }

    private func prepareInstallation() throws {
        if !defaults.bool(forKey: installationMarker) {
            try storage.removeAll()
            defaults.set(true, forKey: installationMarker)
        }
    }

    func versions() throws -> [Libre3IdentityVersion] {
        try prepareInstallation()
        guard let data = try storage.read("versions") else { return [] }
        return try JSONDecoder().decode([Libre3IdentityVersion].self, from: data)
    }

    func selectedVersion() throws -> String? {
        try prepareInstallation()
        return try storage.read("selected").flatMap { String(data: $0, encoding: .utf8) }
    }

    func select(_ version: String) throws {
        _ = try identities(version: version)
        try storage.write(Data(version.utf8), account: "selected")
        Libre3Log.detail("Pairing credentials selected, version=\(version)")
    }

    func identities(version: String) throws -> [Libre3AppIdentity] {
        guard let metadata = try versions().first(where: { $0.id == version }),
            let data = try storage.read("payload." + version)
        else { throw Libre3IdentityError.unavailable }
        return try Self.validate(json: data, digest: metadata.digest)
    }

    /// Returns the selected version offline. Updating the compiled source is explicit in Settings,
    /// so it never silently replaces a sensor's pinned version or authentication key.
    func ensureAvailable() async throws -> Libre3IdentityVersion {
        if let selected = try selectedVersion(), let version = try versions().first(where: { $0.id == selected }),
            (try? identities(version: selected)) != nil
        {
            return version
        }
        let version = try await downloadCurrent()
        try select(version.id)
        return version
    }

    func downloadCurrent() async throws -> Libre3IdentityVersion {
        let source = Libre3IdentitySource.current
        if let cached = try versions().first(where: { $0.id == source.version && $0.digest == source.digest }) {
            if (try? identities(version: cached.id)) != nil {
                if try selectedVersion() == nil { try select(cached.id) }
                return cached
            }
        }
        if let download { return try await download.value }
        let work = Task { () throws -> Libre3IdentityVersion in
            Libre3Log.detail("Pairing credentials download started, version=\(source.version)")
            var validated: Data?
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            for url in source.gateways {
                try Task.checkCancellation()
                do {
                    let (blob, response) = try await session.data(from: url)
                    guard (response as? HTTPURLResponse)?.statusCode == 200, blob.count <= 1_000_000 else {
                        throw Libre3IdentityError.invalidFile
                    }
                    let json = try (blob as NSData).decompressed(using: .lzma) as Data
                    _ = try Self.validate(json: json, digest: source.digest)
                    validated = json
                    break
                } catch is CancellationError { throw CancellationError() } catch {
                    // Only safe error metadata leaves this boundary, never the downloaded file.
                    Libre3Log.failure("Pairing credentials download or validation", error: error)
                    continue
                }
            }
            guard let json = validated else { throw Libre3IdentityError.unavailable }
            let version = try saveValidated(json: json, source: source)
            Libre3Log.detail("Pairing credentials validated and saved, version=\(version.id)")
            return version
        }
        download = work
        defer { download = nil }
        do { return try await work.value } catch {
            Libre3Log.failure("Pairing credentials provisioning", error: error)
            throw error
        }
    }

    /// Immutable version IDs prevent an update from overwriting a sensor's pinned identity set.
    func saveValidated(json: Data, source: Libre3IdentitySource) throws -> Libre3IdentityVersion {
        let identities = try Self.validate(json: json, digest: source.digest)
        var all = try versions()
        if let existing = all.first(where: { $0.id == source.version }) {
            guard existing.digest == source.digest else { throw Libre3IdentityError.invalidFile }
            // Repair an interrupted/missing payload only with the identical validated content.
            try storage.write(json, account: "payload." + existing.id)
            return existing
        }
        let version = Libre3IdentityVersion(
            id: source.version, downloadedAt: Date(), digest: source.digest,
            labels: identities.map(\.label))
        all.append(version)
        // Publish metadata last, a failed write leaves the selected version intact.
        try storage.write(json, account: "payload." + version.id)
        try storage.write(JSONEncoder().encode(all), account: "versions")
        if try selectedVersion() == nil { try select(version.id) }
        return version
    }

    static func validate(json: Data, digest: String) throws -> [Libre3AppIdentity] {
        guard json.count <= 1_000_000,
            SHA256.hash(data: json).map({ String(format: "%02x", $0) }).joined() == digest
        else {
            throw Libre3IdentityError.invalidFile
        }
        struct Payload: Decodable {
            struct Entry: Decodable {
                let label: String
                let privateKeyHex: String
                let certificateHex: String
            }
            let format: Int
            let curve: String
            let identities: [Entry]
        }
        do {
            let file = try JSONDecoder().decode(Payload.self, from: json)
            guard file.format == 1, file.curve == "P-256", !file.identities.isEmpty,
                file.identities.count <= 16, Set(file.identities.map(\.label)).count == file.identities.count
            else {
                throw Libre3IdentityError.invalidFile
            }
            return try file.identities.map { entry in
                try Libre3AppIdentity(
                    label: entry.label,
                    privateKey: decodeHex(entry.privateKeyHex, count: 32),
                    certificate: decodeHex(entry.certificateHex, count: 162))
            }
        } catch { throw Libre3IdentityError.invalidFile }
    }

    private static func decodeHex(_ string: String, count: Int) throws -> Data {
        let bytes = Array(string.utf8)
        guard bytes.count == count * 2 else { throw Libre3IdentityError.invalidFile }
        func nibble(_ byte: UInt8) throws -> UInt8 {
            switch byte {
            case 48...57: return byte - 48
            case 65...70: return byte - 55
            case 97...102: return byte - 87
            default: throw Libre3IdentityError.invalidFile
            }
        }
        return try Data(
            stride(from: 0, to: bytes.count, by: 2).map {
                try nibble(bytes[$0]) << 4 | nibble(bytes[$0 + 1])
            })
    }
}
