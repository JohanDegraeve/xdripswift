//
//  OttaiV3BootstrapPolicy.swift
//  xdrip
//
//  Ottai / Syai CGM driver — decides how a new V3 sensor may get its first keys.
//  This is a Swift copy of OttaiV3BootstrapPolicy.kt from JugglucoNG.
//

import Foundation

/// What to do after the Bluetooth services are found.
enum OttaiAuthEntryMode {
    case storedMaterialAuth
    case v3CredentialBootstrap
    case blocked
}

/// A new V3 sensor has no keyA yet. It may ask the server for one only when the
/// user asked for it, the cloud checked this sensor and version, and the China
/// login is still there. In every other case we do nothing with the sensor's
/// login characteristics.
func ottaiAuthEntryMode(
    hasAuthKeys: Bool,
    bootstrapPending: Bool,
    cnSessionAvailable: Bool,
    validatedDeviceVersion: String?
) -> OttaiAuthEntryMode {
    if hasAuthKeys { return .storedMaterialAuth }
    if bootstrapPending, cnSessionAvailable,
       let v = validatedDeviceVersion, !v.trimmingCharacters(in: .whitespaces).isEmpty {
        return .v3CredentialBootstrap
    }
    return .blocked
}
