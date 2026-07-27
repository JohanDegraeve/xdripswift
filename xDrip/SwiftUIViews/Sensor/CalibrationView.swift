import SwiftUI
import os

struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss

    let canCalibrate: Bool
    let shouldWarnOnLargeCalibrationStep: Bool
    let currentBgDisplay: SensorManagementEnteredBgValue?
    let readiness: CalibrationReadiness
    let isMgDl: Bool
    let onSubmitCalibration: (Double) -> String?
    let onCalibrationSaved: () -> Void

    @State private var calibrationValue = ""
    @State private var showingLargeDifferenceConfirmation = false
    @State private var transientMessage: CalibrationViewMessage?

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataCalibrations)

    var body: some View {
        NavigationView {
            Form {
                readinessSection

                Section(footer: calibrationEntryFooter) {
                    HStack {
                        Text(Texts_BgReadings.calibrationValue)
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
            }
            .navigationTitle(Texts_HomeView.calibrationButton)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: openCalibrationHelp) {
                        Image(systemName: "questionmark.circle")
                    }

                    Button(Texts_HomeView.calibrationButton, action: submitCalibration)
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
        Section(footer: Text(readiness.summary)) {
            readinessRow(title: Texts_HomeView.sensorManagementCalibrationInRange, check: readiness.inRange)
            readinessRow(title: Texts_HomeView.sensorManagementCalibrationStableTrend, check: readiness.stableTrend)
            readinessRow(title: Texts_HomeView.sensorManagementNoiseTitle, check: readiness.sensorNoise)
        }
    }

    private func readinessRow(title: String, check: CalibrationReadinessCheck) -> some View {
        HStack(spacing: 10) {
            Image(systemName: check.level.systemImage)
                .foregroundStyle(check.level.color)
                .frame(width: 22)
            Text(title)
            Spacer()
            Text(check.detail)
                .foregroundStyle(check.level.color)
                .multilineTextAlignment(.trailing)
        }
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
        guard let value = calibrationValue.toDouble(), isCalibrationValueInRange else { return }

        let currentBgDescription = currentBgDisplay?.displayValueWithUnit(isMgDl: isMgDl) ?? "-"
        let calibrationDescription = displayEnteredCalibrationValueWithUnit(value)
        if forcedLargeDelta, largeCalibrationDifferenceWarning != nil {
            trace(
                "in submitCalibration, user forced calibration despite the large delta. current BG = %{public}@, calibration value = %{public}@",
                log: log,
                category: ConstantsLog.categoryApplicationDataCalibrations,
                type: .info,
                currentBgDescription,
                calibrationDescription
            )
        }

        trace(
            "in submitCalibration, user calibrating. current BG = %{public}@, calibration value = %{public}@, readiness: in range = %{public}@, stable trend = %{public}@, sensor noise = %{public}@, warning = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataCalibrations,
            type: .info,
            currentBgDescription,
            calibrationDescription,
            readiness.inRange.traceDescription,
            readiness.stableTrend.traceDescription,
            readiness.sensorNoise.traceDescription,
            largeCalibrationDifferenceWarning ?? "none"
        )

        if let errorMessage = onSubmitCalibration(value) {
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

    private func openCalibrationHelp() {
        let urlString: String
        if let languageCode = NSLocale.current.language.languageCode?.identifier,
           languageCode != ConstantsHomeView.onlineHelpBaseLocale,
           UserDefaults.standard.translateOnlineHelp {
            urlString = ConstantsHomeView.calibrationHelpURLTranslated1 + languageCode + ConstantsHomeView.calibrationHelpURLTranslated2
        } else {
            urlString = ConstantsHomeView.calibrationHelpURL
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
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
