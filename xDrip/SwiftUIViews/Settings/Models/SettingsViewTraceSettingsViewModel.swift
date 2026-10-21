//
//  SettingsViewTraceSettingsViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 2/5/20.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// Supplies the Activity Log row in Troubleshooting.
class SettingsViewTraceSettingsViewModel: NSObject, SettingsViewModelProtocol {
    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [SettingsRow(id: "trace.troubleshootingLog", title: Texts_SettingsView.viewActivityLog,
                     accessory: .disclosure, action: .troubleshootingLog)]
    }

    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}

    func sectionTitle() -> String? { Texts_SettingsView.troubleshootingTitle }

    func settingsSectionFooter() -> String? { nil }

    func settingsRowText(index: Int) -> String { Texts_SettingsView.viewActivityLog }

    func accessoryType(index: Int) -> SettingsAccessory { .disclosure }

    func detailedText(index: Int) -> String? { nil }

    func numberOfRows() -> Int { 1 }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction { .nothing }

    func isEnabled(index: Int) -> Bool { true }

    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
}

@MainActor
extension SettingsViewTraceSettingsViewModel {
    static func issueReportSections(presenter: SettingsActionPresenter) -> [SettingsSectionModel] {
        return [
            SettingsSectionModel(id: 0) {
                SettingsSection(rows: [SettingsRow(id: "trace.warning", title: "", control: .custom {
                    AnyView(HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text(Texts_SettingsView.issueReportSectionFooter).font(.subheadline)
                    }
                    .listRowBackground(Color.clear))
                })])
            },
            SettingsSectionModel(id: 2) {
                SettingsSection(footer: Texts_SettingsView.reportWatchFooter, rows: [
                    SettingsRow(id: "trace.includeWatchLogs", title: Texts_SettingsView.includeWatchLogs,
                                control: .custom { AnyView(IssueReportWatchLogsRow(presenter: presenter)) },
                                isEnabled: presenter.traceWatchLogsAvailable)
                ])
            },
            SettingsSectionModel(id: 3) {
                SettingsSection(footer: Texts_SettingsView.reportSendFooter, rows: [
                    SettingsRow(id: "trace.sendTraceFile", title: Texts_SettingsView.sendTraceFile,
                                control: .custom { AnyView(IssueReportSendRow(presenter: presenter)) })
                ])
            },
            SettingsSectionModel(id: 4) {
                SettingsSection(footer: Texts_SettingsView.reportShareFooter, rows: [
                    SettingsRow(id: "trace.shareReport", title: Texts_SettingsView.shareReport,
                                control: .custom { AnyView(IssueReportSendRow(presenter: presenter, share: true)) })
                ])
            }
        ]
    }
}

private struct IssueReportWatchLogsRow: View {
    @ObservedObject var presenter: SettingsActionPresenter

    var body: some View {
        HStack(spacing: 10) {
            Text(Texts_SettingsView.includeWatchLogs)
                .foregroundStyle(presenter.traceWatchLogsAvailable ? ConstantsAppColors.rowTitleText : ConstantsAppColors.disabledText)
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 8)
            if presenter.preparingTraceEmail {
                ProgressView().controlSize(.small).accessibilityLabel(Texts_SettingsView.requestingWatchLogs)
            }
            Toggle(Texts_SettingsView.includeWatchLogs, isOn: Binding(
                get: { presenter.includeTraceWatchLogs }, set: { presenter.confirmTraceWatchLogs($0) }
            ))
            .labelsHidden().fixedSize().tint(.green)
        }
        .disabled(!presenter.traceWatchLogsAvailable)
        .onReceive(NotificationCenter.default.publisher(for: DirectWatchSettings.changed)) { _ in
            presenter.traceReportConfigurationChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: DirectWatchSettings.statusChanged)) { _ in
            presenter.traceReportConfigurationChanged()
        }
    }
}

private struct IssueReportSendRow: View {
    @ObservedObject var presenter: SettingsActionPresenter
    var share = false

    var body: some View {
        Button {
            if share { presenter.requestTraceShare() } else { presenter.requestTraceEmail() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: share ? "square.and.arrow.up" : "envelope").frame(width: 22)
                Text(share ? Texts_SettingsView.shareReport : Texts_SettingsView.sendTraceFile)
                Spacer(minLength: 8)
                if presenter.preparingTraceEmail {
                    Text(Texts_SettingsView.requestingWatchLogs).foregroundStyle(ConstantsAppColors.disabledText)
                } else {
                    SettingsDisclosureIndicator()
                }
            }
            .lineLimit(1).minimumScaleFactor(0.75)
            .foregroundStyle(presenter.preparingTraceEmail ? ConstantsAppColors.disabledText : ConstantsAppColors.navigationTint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(presenter.preparingTraceEmail)
    }
}
