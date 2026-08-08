//
//  FollowerServiceStatusMonitor.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// Availability reported by a provider's public status endpoint.
/// It is operational information and is not evidence that the user's account is connected.
enum FollowerOperationalStatus: Equatable {
    case checking
    case available
    case degraded
    case outage
    case unavailable
    case fetchError

    var title: String {
        switch self {
        case .checking: return Texts_Common.checking
        case .available: return Texts_SettingsView.followerOperational
        case .degraded: return Texts_SettingsView.followerDegraded
        case .outage: return Texts_SettingsView.followerOutage
        case .unavailable: return Texts_Common.notAvailable
        case .fetchError: return Texts_SettingsView.followerFetchError
        }
    }

    var color: Color {
        switch self {
        case .checking, .unavailable: return .gray
        case .available: return ConstantsAppColors.normal
        case .degraded: return .orange
        case .outage, .fetchError: return ConstantsAppColors.urgent
        }
    }
}

final class FollowerServiceStatusMonitor: ObservableObject {
    @Published private(set) var status: FollowerOperationalStatus = .checking
    @Published private(set) var lastCheckedAt: Date?

    let source: FollowerDataSourceType
    private var timer: Timer?
    private var task: Task<Void, Never>?

    init(source: FollowerDataSourceType) {
        self.source = source
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
        task?.cancel()
    }

    func refresh() {
        task?.cancel()
        status = .checking
        task = Task { [weak self] in
            guard let self else { return }
            let result = await Self.fetch(source: source)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.status = result
                self.lastCheckedAt = Date()
            }
        }
    }

    var statusPageURL: URL? {
        Self.endpoint(source: source)?.statusPageURL
    }

    nonisolated static func statusURL(
        source: FollowerDataSourceType,
        defaults: UserDefaults = .standard
    ) -> URL? {
        endpoint(source: source, defaults: defaults)?.statusURL
    }

    nonisolated static func decode(
        source: FollowerDataSourceType,
        data: Data,
        httpStatus: Int
    ) -> FollowerOperationalStatus {
        guard (200 ... 299).contains(httpStatus) else { return .fetchError }
        do {
            switch source {
            case .nightscout:
                let indicator = try JSONDecoder().decode(NightscoutStatusPayload.self, from: data).status
                return map(indicator: indicator)
            case .dexcomShare, .libreLinkUp, .libreLinkUpRussia:
                let indicator = try JSONDecoder().decode(StatusPagePayload.self, from: data).status.indicator
                return map(indicator: indicator)
            case .medtrumEasyView, .calendar, .careLink:
                return .unavailable
            }
        } catch {
            return .fetchError
        }
    }

    nonisolated static func fetch(source: FollowerDataSourceType) async -> FollowerOperationalStatus {
        guard let url = statusURL(source: source) else { return .unavailable }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse else { return .fetchError }
            return decode(source: source, data: data, httpStatus: response.statusCode)
        } catch {
            return .fetchError
        }
    }

    private nonisolated static func endpoint(
        source: FollowerDataSourceType,
        defaults: UserDefaults = .standard
    ) -> FollowerServiceEndpoint? {
        switch source {
        case .nightscout:
            guard let urlString = defaults.nightscoutUrl,
                  var components = URLComponents(string: urlString),
                  components.scheme != nil,
                  components.host != nil else { return nil }
            if (1 ... 65_535).contains(defaults.nightscoutPort) {
                components.port = defaults.nightscoutPort
            }
            guard let url = components.url else { return nil }
            return FollowerServiceEndpoint(
                statusPageURL: url,
                apiPath: ConstantsFollower.followerStatusNightscoutApiPath
            )

        case .dexcomShare:
            return FollowerServiceEndpoint(
                statusPageURL: URL(string: ConstantsFollower.followerStatusDexcomBaseUrl)!,
                apiPath: ConstantsFollower.followerStatusAtlassianApiPath
            )

        case .libreLinkUp, .libreLinkUpRussia:
            return FollowerServiceEndpoint(
                statusPageURL: URL(string: ConstantsFollower.followerStatusAbbottBaseUrl)!,
                apiPath: ConstantsFollower.followerStatusAtlassianApiPath
            )

        case .medtrumEasyView, .calendar, .careLink:
            return nil
        }
    }

    private nonisolated static func map(indicator: String) -> FollowerOperationalStatus {
        switch indicator.lowercased() {
        case "none", "ok": return .available
        case "minor", "major", "degraded_performance", "partial_outage": return .degraded
        case "critical", "major_outage": return .outage
        default: return .degraded
        }
    }
}

private struct FollowerServiceEndpoint {
    let statusPageURL: URL
    let apiPath: String

    var statusURL: URL? {
        guard var components = URLComponents(url: statusPageURL, resolvingAgainstBaseURL: false) else { return nil }
        let pathParts = components.path.split(separator: "/") + apiPath.split(separator: "/")
        components.path = "/" + pathParts.joined(separator: "/")
        return components.url
    }
}

private struct NightscoutStatusPayload: Decodable {
    let status: String
}

private struct StatusPagePayload: Decodable {
    struct Summary: Decodable {
        let indicator: String
    }

    let status: Summary
}
