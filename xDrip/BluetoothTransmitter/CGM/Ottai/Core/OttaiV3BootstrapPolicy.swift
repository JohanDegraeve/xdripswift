//
//  OttaiV3BootstrapPolicy.swift
//  xdrip
//
//  Ottai / Syai CGM driver — how a connection starts when the sensor has no keyA yet.
//

import Foundation

enum OttaiAuthEntryMode {
    case storedMaterialAuth
    /// Activated through the server; only the bind (which gives keyA) is missing.
    case awaitingBind
    /// New sensor, the user asked to activate it: the server answers the login.
    case serverAssistedActivation
    case blocked
}

/// A sensor without keyA is only touched when the user asked for activation, the V3
/// check marked it (`bootstrapPending`) and the login is still there.
func ottaiAuthEntryMode(
    hasAuthKeys: Bool,
    pendingBind: Bool,
    bootstrapPending: Bool,
    sessionAvailable: Bool,
    activationRequested: Bool
) -> OttaiAuthEntryMode {
    if hasAuthKeys { return .storedMaterialAuth }
    if pendingBind { return .awaitingBind }
    if bootstrapPending, sessionAvailable, activationRequested { return .serverAssistedActivation }
    return .blocked
}
