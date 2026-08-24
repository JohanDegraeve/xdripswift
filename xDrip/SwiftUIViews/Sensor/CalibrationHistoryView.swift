//
//  CalibrationHistoryView.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Shows the current calibration and previous calibrations for the active sensor.
struct CalibrationHistoryView: View {
    let currentCalibration: SensorManagementCalibrationDisplay?
    let calibrationHistory: [SensorManagementCalibrationDisplay]
    let isMgDl: Bool

    var body: some View {
        List {
            if let currentCalibration {
                Section(header: Text(Texts_HomeView.sensorManagementCurrentCalibrationTitle)) {
                    calibrationSummaryView(calibration: currentCalibration, isHistoric: false)
                }
            }

            if !calibrationHistory.isEmpty {
                Section(header: Text(Texts_HomeView.sensorManagementHistoryTitle)) {
                    ForEach(calibrationHistory, id: \.id) { calibration in
                        calibrationSummaryView(calibration: calibration, isHistoric: !calibration.isValid)
                    }
                }
            }
        }
        .navigationTitle(Texts_HomeView.sensorManagementHistoryTitle)
    }

    private func calibrationSummaryView(calibration: SensorManagementCalibrationDisplay, isHistoric: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(calibration.timeStamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.colorPrimary))
                Spacer()
                if isHistoric {
                    Text(Texts_HomeView.sensorManagementHistoricCalibration)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
            }

            valueRow(title: Texts_HomeView.sensorManagementCalibrationBG, value: displayBgValue(calibration.bg), isHistoric: isHistoric)

            if calibration.showsCalculatedDetails {
                valueRow(
                    title: Texts_HomeView.sensorManagementCalibrationRaw,
                    value: calibration.rawValue.bgValueToString(mgDl: true) + " " + Texts_Common.mgdl,
                    isHistoric: isHistoric
                )
                valueRow(
                    title: Texts_HomeView.sensorManagementCalibrationSlope,
                    value: calibration.slope.formatted(.number.rounded(increment: 0.0001)),
                    isHistoric: isHistoric
                )
                valueRow(
                    title: Texts_HomeView.sensorManagementCalibrationIntercept,
                    value: calibration.intercept.formatted(.number.rounded(increment: 0.0001)),
                    isHistoric: isHistoric
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func valueRow(title: String, value: String, isHistoric: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color(.colorSecondary))
            Spacer()
            Text(value)
                .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
        }
    }

    private func displayBgValue(_ valueInMgDl: Double) -> String {
        valueInMgDl
            .mgDlToMmol(mgDl: isMgDl)
            .bgValueRounded(mgDl: isMgDl)
            .bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }
}

struct SensorManagementCalibrationDisplay {
    let id: String
    let timeStamp: Date
    let slope: Double
    let intercept: Double
    let bg: Double
    let rawValue: Double
    let isValid: Bool

    init(_ calibration: Calibration) {
        id = calibration.id
        timeStamp = calibration.timeStamp
        slope = calibration.slope
        intercept = calibration.intercept
        bg = calibration.bg
        rawValue = calibration.rawValue
        isValid = calibration.sensorConfidence != 0 && calibration.slopeConfidence != 0
    }

    var showsCalculatedDetails: Bool {
        abs(slope) > 0.0001 || abs(intercept) > 0.0001
    }
}
