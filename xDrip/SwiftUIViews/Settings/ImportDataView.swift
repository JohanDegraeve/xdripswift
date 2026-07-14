//
//  ImportDataView.swift
//  xdrip
//
//  Created by Paul Plant on 14/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

// MARK: - Import Data Source

/// Defines the import destinations shown by Data Management so new providers can be added centrally.
enum ImportDataSource: String, CaseIterable, Identifiable {
    case nightscout

    var id: Self { self }

    var title: String {
        switch self {
        case .nightscout: Texts_SettingsView.sectionTitleNightscout
        }
    }

}

// MARK: - Import Data View

struct ImportDataView: View {
    private let coreDataManager: CoreDataManager

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    var body: some View {
        Form {
            Section {
                ForEach(ImportDataSource.allCases) { source in
                    NavigationLink {
                        destination(for: source)
                            .navigationTitle(source.title)
                            .navigationBarTitleDisplayMode(.large)
                    } label: {
                        Text(source.title)
                    }
                }
            }
        }
        .tint(Color(.systemBlue))
    }

    @ViewBuilder
    private func destination(for source: ImportDataSource) -> some View {
        switch source {
        case .nightscout:
            NightscoutImportView(coreDataManager: coreDataManager)
        }
    }
}
