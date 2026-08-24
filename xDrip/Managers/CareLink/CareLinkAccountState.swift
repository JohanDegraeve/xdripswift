//
//  CareLinkAccountState.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import Foundation

/// Main-thread observable facade shared by the UIKit Settings model and SwiftUI status screen.
/// The manager owns behavior. This object owns only a publishable snapshot and weak commands.
final class CareLinkAccountState: ObservableObject {
    /// One shared instance prevents two Settings presentations from observing divergent state.
    static let shared = CareLinkAccountState()

    @Published private(set) var snapshot = CareLinkStatusSnapshot()
    /// Weak to avoid a cycle with the application-owned long-lived manager.
    weak var controller: CareLinkControlling?

    /// Publishes a complete value after mutation so the UI never observes a half-updated snapshot.
    func update(_ transform: @escaping (inout CareLinkStatusSnapshot) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.update(transform) }
            return
        }
        var next = snapshot
        transform(&next)
        // Published replays rebuild Home consumers, so do not emit when no account state changed.
        guard next != snapshot else { return }
        snapshot = next
    }

    func logIn() { controller?.logIn() }
    func refresh() { controller?.refresh() }
    func logOut() { controller?.logOut() }
    func changeRegion() { controller?.changeRegion() }
    func setRegion(_ region: CareLinkRegion) { controller?.setRegion(region) }
    func selectPatient(_ id: String) { controller?.selectPatient(id) }
}

/// Commands exposed to Settings without coupling the views to manager implementation details.
protocol CareLinkControlling: AnyObject {
    func logIn()
    func refresh()
    func logOut()
    func changeRegion()
    func setRegion(_ region: CareLinkRegion)
    func selectPatient(_ id: String)
}
