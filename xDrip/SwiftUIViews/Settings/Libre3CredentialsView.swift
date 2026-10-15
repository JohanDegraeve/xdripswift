//
//  Libre3CredentialsView.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct Libre3CredentialsView: View {
    @State private var versions: [Libre3IdentityVersion] = []
    @State private var selected = ""
    @State private var busy = false
    @State private var message: String?
    @State private var downloadResult = ""
    @State private var showsDownloadResult = false

    var body: some View {
        Form {
            Section {
                if versions.isEmpty {
                    Label(TextsLibre3.localized("No Libre 3 credentials downloaded"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label(TextsLibre3.localized("Downloaded and ready for pairing"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Picker(Texts_SettingsView.version, selection: $selected) {
                        ForEach(versions) { version in
                            Text(version.downloadedAt.formatted(date: .abbreviated, time: .omitted))
                                .tag(version.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selected) { value in
                        guard !value.isEmpty else { return }
                        Task {
                            do { try await Libre3IdentityStore.shared.select(value) } catch {
                                message = error.localizedDescription
                                await reload()
                            }
                        }
                    }
                }
            } header: {
                Text(TextsLibre3.localized("Pairing credentials"))
            } footer: {
                Text(TextsLibre3.localized("Credentials are downloaded automatically during sensor setup. Change the selected version here only when testing or troubleshooting."))
            }
            Section {
                Button {
                    busy = true
                    message = nil
                    Task {
                        defer { busy = false }
                        do {
                            let previousVersions = try await Libre3IdentityStore.shared.versions()
                            let downloaded = try await Libre3IdentityStore.shared.downloadCurrent()
                            await reload()
                            let alreadyDownloaded = previousVersions.contains {
                                $0.id == downloaded.id && $0.digest == downloaded.digest && $0.downloadedAt == downloaded.downloadedAt
                            }
                            downloadResult = TextsLibre3.localized(
                                alreadyDownloaded
                                    ? "No new credentials available"
                                    : "New credentials downloaded")
                            showsDownloadResult = true
                        } catch { message = error.localizedDescription }
                    }
                } label: {
                    Label(TextsLibre3.localized("Download Latest Credentials"), systemImage: "arrow.down.circle")
                }
                if busy { ProgressView() }
                if let message { Text(message).foregroundStyle(.secondary) }
            } footer: {
                Text(
                    TextsLibre3.localized(
                        "Downloads are validated and stored on this device. Previous versions are kept. Changing this selection affects the next NFC pairing. It does not change a connected sensor. To change an active sensor's version, select it here and scan again using the original Receiver ID. Saved sensor connections work offline."
                    ))
            }
        }
        .disabled(busy)
        .navigationTitle(TextsLibre3.localized("Libre 3 Credentials"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .alert(TextsLibre3.localized("Libre 3 Credentials"), isPresented: $showsDownloadResult) {
            Button(Texts_Common.Ok, role: .cancel) {}
        } message: {
            Text(downloadResult)
        }
    }

    @MainActor private func reload() async {
        do {
            versions = try await Libre3IdentityStore.shared.versions()
            selected = try await Libre3IdentityStore.shared.selectedVersion() ?? ""
        } catch { message = error.localizedDescription }
    }
}
