//
//  CalibrationView.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import os

/// Collects a calibration value and shows the checks that affect calibration quality.
struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss

    let canCalibrate: Bool
    let shouldWarnOnLargeCalibrationStep: Bool
    let currentBgDisplay: SensorManagementEnteredBgValue?
    let readiness: CalibrationReadiness
    let isMgDl: Bool
    let onSubmitCalibration: (CalibrationSubmission) -> String?
    let onCalibrationSaved: () -> Void

    @State private var calibrationValue = ""
    @State private var showingLargeDifferenceConfirmation = false
    @State private var transientMessage: CalibrationViewMessage?

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataCalibrations)

    var body: some View {
        NavigationView {
            Form {
                Section(footer: calibrationEntryFooter) {
                    HStack {
                        Text(Texts_HomeView.sensorManagementCalibrationValue)
                        Spacer()
                        TextField(currentBgDisplay?.rawValue ?? (isMgDl ? "---" : "-.-"), text: $calibrationValue)
                            .keyboardType(isMgDl ? .numberPad : .decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 96)
                            .foregroundStyle(calibrationValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.colorSecondary) : Color(.colorPrimary))
                        Text(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
                            .foregroundStyle(Color(.colorTertiary))
                    }
                }

                readinessSection
            }
            .navigationTitle(Texts_HomeView.calibrationButton)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        dismiss()
                    }
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    OnlineHelpButton(topic: .calibration)

                    Button(Texts_HomeView.calibrationButton, action: submitCalibration)
                        .tint(ConstantsAppColors.toolbarAction)
                        .disabled(!canCalibrate || !isCalibrationValueInRange)
                }
            }
        }
        .colorScheme(.dark)
        .alert(item: $transientMessage) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text(Texts_Common.Ok)))
        }
        .alert(Texts_Common.warning, isPresented: $showingLargeDifferenceConfirmation) {
            Button(Texts_Common.Cancel, role: .cancel) {}
            Button(Texts_HomeView.calibrationButton) {
                executeCalibration(forcedLargeDelta: true)
            }
        } message: {
            Text(largeCalibrationDifferenceWarning ?? "")
        }
    }

    private var readinessSection: some View {
        Section {
            readinessRow(title: Texts_HomeView.sensorManagementCalibrationStableTrend, check: readiness.stableTrend)
            readinessRow(title: Texts_HomeView.sensorManagementNoiseTitle, check: readiness.sensorNoise)
            readinessRow(
                title: Texts_HomeView.sensorManagementCalibrationValue,
                check: evaluatedReadiness?.calibrationValue
            )
        } footer: {
            if let evaluatedReadiness {
                Text(
                    evaluatedReadiness.level == .bad
                        ? "⚠️ \(evaluatedReadiness.summary)"
                        : evaluatedReadiness.summary
                )
            }
        }
    }

    private func readinessRow(title: String, check: CalibrationReadinessCheck?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: check?.level.systemImage ?? "ellipsis.circle.fill")
                .foregroundStyle(check?.level.color ?? ConstantsAppColors.tertiaryText)
                .frame(width: 22)
            Text(title)
            Spacer()
            Text(check?.detail ?? Texts_HomeView.sensorManagementCalibrationPending)
                .foregroundStyle(check?.level.color ?? ConstantsAppColors.tertiaryText)
                .multilineTextAlignment(.trailing)
        }
        .listRowBackground(readinessSectionBackgroundColor)
    }

    private var calibrationEntryFooter: some View {
        Group {
            if let warningMessage = largeCalibrationDifferenceWarning {
                Text(warningMessage)
                    .foregroundStyle(Color(.systemOrange))
            } else {
                Text(Texts_HomeView.sensorManagementCalibrationSafetyFooter)
            }
        }
    }

    private var enteredCalibrationValueInMgDl: Double? {
        calibrationValue.toDouble()?.mmolToMgdl(mgDl: isMgDl)
    }

    private var isCalibrationValueInRange: Bool {
        guard let enteredCalibrationValueInMgDl else { return false }
        return enteredCalibrationValueInMgDl >= ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl &&
            enteredCalibrationValueInMgDl <= ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
    }

    /// The entered fingerstick provides the range check. Trend and noise continue to come from
    /// the sensor's recent readings because a single fingerstick cannot establish either.
    private var evaluatedReadiness: CalibrationReadinessEvaluation? {
        guard isCalibrationValueInRange, let enteredCalibrationValueInMgDl else { return nil }
        return readiness.evaluating(calibrationValueInMgDl: enteredCalibrationValueInMgDl)
    }

    private var readinessSectionBackgroundColor: Color {
        guard let evaluatedReadiness else { return ConstantsUI.normalSectionBackgroundColor }

        switch evaluatedReadiness.level {
        case .good:
            return ConstantsUI.activeRowBackgroundColor
        case .caution:
            return ConstantsUI.cautionSectionBackgroundColor
        case .bad:
            return ConstantsUI.warningSectionBackgroundColor
        }
    }

    private var largeCalibrationDifferenceWarning: String? {
        guard let currentBgDisplay, let enteredCalibrationValueInMgDl, isCalibrationValueInRange else { return nil }
        let differenceInMgDl = abs(enteredCalibrationValueInMgDl - currentBgDisplay.valueInMgDl)
        guard differenceInMgDl > ConstantsCalibrationAlgorithms.maximumRecommendedCalibrationDifferenceInMgDl else { return nil }

        return String(
            format: Texts_HomeView.sensorManagementLargeCalibrationDifferenceWarningFormat,
            displayCalibrationDifferenceLimit()
        )
    }

    private func submitCalibration() {
        guard isCalibrationValueInRange else { return }
        if shouldWarnOnLargeCalibrationStep, largeCalibrationDifferenceWarning != nil {
            showingLargeDifferenceConfirmation = true
        } else {
            executeCalibration()
        }
    }

    private func executeCalibration(forcedLargeDelta: Bool = false) {
        guard let value = calibrationValue.toDouble(), let evaluatedReadiness else { return }

        let currentBgDescription = currentBgDisplay?.displayValueWithUnit(isMgDl: isMgDl) ?? "-"
        let calibrationDescription = displayEnteredCalibrationValueWithUnit(value)
        if forcedLargeDelta, largeCalibrationDifferenceWarning != nil {
            trace(
                "in submitCalibration, user forced calibration despite the large delta. current BG = %{public}@, calibration value = %{public}@, readiness: %{public}@",
                log: log,
                category: ConstantsLog.categoryApplicationDataCalibrations,
                type: .info,
                currentBgDescription,
                calibrationDescription,
                evaluatedReadiness.traceDescription
            )
        }

        trace(
            "calibration guidance submitted. current BG = %{public}@, calibration value = %{public}@, readiness: %{public}@, large difference warning = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataCalibrations,
            type: .info,
            currentBgDescription,
            calibrationDescription,
            evaluatedReadiness.traceDescription,
            largeCalibrationDifferenceWarning == nil ? "none" : "shown"
        )

        let submission = CalibrationSubmission(enteredValue: value, readiness: evaluatedReadiness)
        if let errorMessage = onSubmitCalibration(submission) {
            transientMessage = CalibrationViewMessage(title: Texts_Common.warning, message: errorMessage)
        } else {
            onCalibrationSaved()
            dismiss()
        }
    }

    private func displayCalibrationDifferenceLimit() -> String {
        let value = ConstantsCalibrationAlgorithms.maximumRecommendedCalibrationDifferenceInMgDl
            .mgDlToMmol(mgDl: isMgDl)
            .bgValueRounded(mgDl: isMgDl)
        return value.bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func displayEnteredCalibrationValueWithUnit(_ value: Double) -> String {
        let roundedValue = value.bgValueRounded(mgDl: isMgDl)
        return roundedValue.bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

}

struct SensorManagementEnteredBgValue {
    let rawValue: String
    let valueInMgDl: Double

    func displayValueWithUnit(isMgDl: Bool) -> String {
        rawValue + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }
}

private struct CalibrationViewMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
