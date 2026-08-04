//
//  SensorStartView.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Collects the start time for sensor types that do not require a sensor code.
struct SensorStartDateView: View {
    let onCancel: () -> Void
    let onStart: (Date) -> Void

    @State private var selectedStartDate = Date()

    var body: some View {
        NavigationView {
            Form {
                if !UserDefaults.standard.startSensorTimeInfoGiven {
                    Section {
                        Text(Texts_HomeView.startSensorTimeInfo)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                Section(header: Text(Texts_HomeView.startSensorActionTitle)) {
                    DatePicker(
                        Texts_HomeView.sensorStart,
                        selection: $selectedStartDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle(Texts_HomeView.startSensorActionTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: onCancel)
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok) {
                        UserDefaults.standard.startSensorTimeInfoGiven = true
                        onStart(selectedStartDate)
                    }
                    .tint(ConstantsAppColors.toolbarAction)
                }
            }
        }
        .colorScheme(.dark)
    }
}

/// Collects and validates a Dexcom G6 sensor code before starting the session.
struct SensorStartCodeView: View {
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var sensorCode = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(Texts_HomeView.enterSensorCode)
                        .foregroundStyle(Color(.colorSecondary))
                }

                Section(header: Text(Texts_HomeView.startSensorActionTitle)) {
                    TextField("0000", text: $sensorCode)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(Texts_HomeView.startSensorActionTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: onCancel)
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok) {
                        onSubmit(sensorCode.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .tint(ConstantsAppColors.toolbarAction)
                    .disabled(!isSensorCodeValid)
                }
            }
        }
        .colorScheme(.dark)
    }

    private var isSensorCodeValid: Bool {
        let trimmedCode = sensorCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCode.isEmpty || (trimmedCode.count == 4 && trimmedCode.allSatisfy(\.isNumber))
    }
}
