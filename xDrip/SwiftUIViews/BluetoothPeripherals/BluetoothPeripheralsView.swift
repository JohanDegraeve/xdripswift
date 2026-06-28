//
//  BluetoothPeripheralsView.swift
//  xdrip
//
//  Created by Paul Plant on 19/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct BluetoothPeripheralsView: View {
    @ObservedObject var viewModel: BluetoothPeripheralsViewModel
    @ObservedObject var router: BluetoothPeripheralsRouter

    var body: some View {
        List {
            if viewModel.sections.isEmpty {
                Text(Texts_BluetoothPeripheralsView.noBluetoothPeripheralsConfigured)
                    .foregroundStyle(Color(.colorSecondary))
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            Button {
                                open(row: row)
                            } label: {
                                BluetoothPeripheralListRowView(row: row)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .listRowBackground(row.connectionStatus.rowBackgroundColor)
                        }
                    } header: {
                        BluetoothPeripheralSectionHeaderView(section: section)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(Texts_BluetoothPeripheralsView.screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: showAddFlow) {
                    Image(systemName: "plus")
                }
                .tint(.yellow)
            }
        }
        .alert(item: $viewModel.pendingAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(Texts_Common.Ok))
            )
        }
        .onAppear(perform: startStatusUpdates)
        .onDisappear(perform: stopStatusUpdates)
    }

    private func showAddFlow() {
        router.showAddPeripheralCategories?()
    }

    private func open(row: BluetoothPeripheralListRow) {
        router.openPeripheral?(row.bluetoothPeripheral, row.bluetoothPeripheral.bluetoothPeripheralType())
    }

    private func startStatusUpdates() {
        viewModel.startStatusUpdates()
    }

    private func stopStatusUpdates() {
        viewModel.stopStatusUpdates()
    }
}

struct BluetoothPeripheralCategorySelectionView: View {
    @ObservedObject var viewModel: BluetoothPeripheralsViewModel
    @ObservedObject var router: BluetoothPeripheralsRouter

    var body: some View {
        List {
            Section {
                ForEach(BluetoothPeripheralCategory.allCases, id: \.rawValue) { category in
                    Button {
                        select(category: category)
                    } label: {
                        BluetoothPeripheralSelectionRow(
                            title: category.rawValue,
                            subtitle: subtitle(for: category),
                            systemImage: category.systemImage()
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(Texts_BluetoothPeripheralsView.selectCategory)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
        .alert(item: $viewModel.pendingAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(Texts_Common.Ok))
            )
        }
    }

    private func select(category: BluetoothPeripheralCategory) {
        guard viewModel.validateCanAdd(category: category) else { return }

        router.showPeripheralTypes?(category)
    }

    private func subtitle(for category: BluetoothPeripheralCategory) -> String {
        let count = viewModel.bluetoothPeripheralTypes(for: category).count
        return count == 1 ? "1 type" : "\(count) types"
    }

}

struct BluetoothPeripheralTypeSelectionView: View {
    let category: BluetoothPeripheralCategory

    @ObservedObject var viewModel: BluetoothPeripheralsViewModel
    @ObservedObject var router: BluetoothPeripheralsRouter

    var body: some View {
        List {
            Section {
                ForEach(viewModel.bluetoothPeripheralTypes(for: category), id: \.rawValue) { bluetoothPeripheralType in
                    Button {
                        open(type: bluetoothPeripheralType)
                    } label: {
                        BluetoothPeripheralSelectionRow(
                            title: bluetoothPeripheralType.rawValue,
                            subtitle: nil,
                            systemImage: category.systemImage()
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
    }

    private func open(type bluetoothPeripheralType: BluetoothPeripheralType) {
        router.openPeripheral?(nil, bluetoothPeripheralType)
    }
}

private struct BluetoothPeripheralListRowView: View {
    let row: BluetoothPeripheralListRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.connectionStatus.antennaSystemImage)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(row.connectionStatus.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .fontWeight(row.connectionStatus.isActive ? .bold : .regular)
                    .foregroundStyle(row.connectionStatus.isActive ? Color(.colorPrimary) : Color(.colorSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(row.typeTitle)
                    .font(.footnote)
                    .foregroundStyle(Color(.colorTertiary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.connectionStatus.statusText)
                .font(.subheadline)
                .foregroundStyle(Color(.colorSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.colorTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct BluetoothPeripheralSectionHeaderView: View {
    let section: BluetoothPeripheralsSection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ConstantsUI.settingsSectionHeaderIconColor)
                .frame(width: 16)

            Text(section.title)
                .foregroundStyle(Color(ConstantsUI.tableViewHeaderTextColor))
        }
    }
}

private extension BluetoothPeripheralDisplayStatus {
    var tintColor: Color {
        switch self {
        case .notScanning:
            return Color(.colorTertiary)
        case .scanning, .connected:
            return .green
        }
    }

    var isActive: Bool {
        switch self {
        case .notScanning:
            return false
        case .scanning, .connected:
            return true
        }
    }

    var rowBackgroundColor: Color {
        switch self {
        case .notScanning:
            return Color(.secondarySystemGroupedBackground)
        case .scanning, .connected:
            return ConstantsUI.activeRowBackgroundColor
        }
    }

    var antennaSystemImage: String {
        switch self {
        case .notScanning:
            return "antenna.radiowaves.left.and.right.slash"
        case .scanning, .connected:
            return "antenna.radiowaves.left.and.right"
        }
    }

    var statusText: String {
        switch self {
        case .notScanning:
            return Texts_BluetoothPeripheralView.notTryingToConnect
        case .scanning:
            return Texts_BluetoothPeripheralView.tryingToConnect
        case .connected:
            return Texts_BluetoothPeripheralView.connected
        }
    }
}

private struct BluetoothPeripheralSelectionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.colorSecondary))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(Color(.colorPrimary))
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(.colorTertiary))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.colorTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
