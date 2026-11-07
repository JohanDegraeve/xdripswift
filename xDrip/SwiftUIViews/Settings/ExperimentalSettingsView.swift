//
//  ExperimentalSettingsView.swift
//  xdrip
//
//  Settings > Experimental features: glucose prediction, insulins on the chart and the glucose
//  line style. The prediction and insulin models are ported from JugglucoNG.
//

import SwiftUI

extension SettingsViewGroupedSettingsViewModel {
    /// The Experimental features root section.
    static func experimental() -> SettingsViewGroupedSettingsViewModel {
        SettingsViewGroupedSettingsViewModel(
            title: ExperimentalTexts.text("sectionTitle", "Experimental features"),
            rows: [
                SettingsGroupedRow(
                    id: "experimental.prediction",
                    title: ExperimentalTexts.text("prediction", "Glucose prediction"),
                    detail: { UserDefaults.standard.experimentalPredictionEnabled ? Texts_Common.on : Texts_Common.off },
                    settingsScreen: { ExperimentalSettingsViewModel.predictionScreen }
                ),
                SettingsGroupedRow(
                    id: "experimental.insulins",
                    title: ExperimentalTexts.text("insulins", "Insulins"),
                    detail: { UserDefaults.standard.experimentalInsulinsEnabled ? Texts_Common.on : Texts_Common.off },
                    settingsScreen: { ExperimentalSettingsViewModel.insulinScreen }
                )
            ],
            leadingRows: { [ExperimentalSettingsViewModel.chartStyleRow()] }
        )
    }
}

struct ExperimentalSettingsViewModel: SettingsNativeSectionProvider {
    enum Group { case predictionMain, predictionModel, insulins }
    let group: Group

    static var predictionScreen: SettingsScreen {
        SettingsScreen(title: ExperimentalTexts.text("prediction", "Glucose prediction"),
                       introduction: { ExperimentalTexts.text("predictionIntroduction", "Experimental. A forecast of the next hours, drawn as a dashed line to the right of the main chart. It continues the recent trend and adds the effect of the carbs, boluses and exercise you log. It is an estimate only: never dose insulin from it.") },
                       providers: { [ExperimentalSettingsViewModel(group: .predictionMain), ExperimentalSettingsViewModel(group: .predictionModel)] })
    }

    static var insulinScreen: SettingsScreen {
        SettingsScreen(title: ExperimentalTexts.text("insulins", "Insulins"),
                       introduction: { ExperimentalTexts.text("insulinsIntroduction", "Experimental. Each insulin has its own action curve, from JugglucoNG's catalogue. A bolus or basal injection uses the insulin named in its notes; the treatment editor offers a choice. Otherwise the defaults below apply.") },
                       providers: { [ExperimentalSettingsViewModel(group: .insulins)] })
    }

    /// Glucose drawn as dots or as a line.
    static func chartStyleRow() -> SettingsRow {
        SettingsRow(id: "experimental.chartStyle", title: ExperimentalTexts.text("chartStyle", "Glucose on the chart"), accessory: .none,
                    control: .menu(options: {
                        let selected = UserDefaults.standard.experimentalGlucoseChartStyle
                        return ExperimentalGlucoseChartStyle.allCases.map { SettingsMenuOption(title: title(for: $0), isSelected: $0 == selected) }
                    }, selectOption: { index in
                        let styles = ExperimentalGlucoseChartStyle.allCases
                        guard styles.indices.contains(index) else { return }
                        UserDefaults.standard.experimentalGlucoseChartStyle = styles[index]
                    }))
    }

    static func title(for style: ExperimentalGlucoseChartStyle) -> String {
        switch style {
        case .points: return ExperimentalTexts.text("chartStylePoints", "Points")
        case .line: return ExperimentalTexts.text("chartStyleLine", "Line")
        }
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let defaults = UserDefaults.standard
        switch group {
        case .predictionMain:
            return [
                SettingsRow(id: "experimental.prediction.enabled", title: ExperimentalTexts.text("predictionShow", "Show prediction"),
                            control: .toggle(isOn: { UserDefaults.standard.experimentalPredictionEnabled },
                                             setIsOn: { UserDefaults.standard.experimentalPredictionEnabled = $0 }),
                            reloadScope: .all),
                SettingsRow(id: "experimental.prediction.horizon", title: ExperimentalTexts.text("predictionHorizon", "Forecast length"), accessory: .none,
                            control: .menu(options: {
                                let selected = UserDefaults.standard.experimentalPredictionHorizonMinutes
                                return ExperimentalPredictionHorizon.choices.map { SettingsMenuOption(title: Self.minutesText($0), isSelected: $0 == selected) }
                            }, selectOption: { index in
                                let choices = ExperimentalPredictionHorizon.choices
                                guard choices.indices.contains(index) else { return }
                                UserDefaults.standard.experimentalPredictionHorizonMinutes = choices[index]
                            }),
                            isEnabled: defaults.experimentalPredictionEnabled),
                SettingsRow(id: "experimental.prediction.momentum", title: ExperimentalTexts.text("predictionMomentum", "Follow the trend"),
                            control: .toggle(isOn: { UserDefaults.standard.experimentalPredictionTrendMomentum },
                                             setIsOn: { UserDefaults.standard.experimentalPredictionTrendMomentum = $0 }),
                            isEnabled: defaults.experimentalPredictionEnabled)
            ]
        case .predictionModel:
            let isMgDl = defaults.bloodGlucoseUnitIsMgDl
            let unit = isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
            return [
                numberRow(id: "experimental.prediction.sensitivity", title: ExperimentalTexts.text("predictionSensitivity", "Insulin sensitivity (per unit)"),
                          value: defaults.experimentalPredictionInsulinSensitivityMgDl.mgDlToMmol(mgDl: isMgDl),
                          unit: unit, fractionDigits: isMgDl ? 0 : 1,
                          range: ExperimentalPredictionModel.insulinSensitivityRange.lowerBound.mgDlToMmol(mgDl: isMgDl)...ExperimentalPredictionModel.insulinSensitivityRange.upperBound.mgDlToMmol(mgDl: isMgDl),
                          isEnabled: defaults.experimentalPredictionEnabled) { value in
                    UserDefaults.standard.experimentalPredictionInsulinSensitivityMgDl = isMgDl ? value : value / ConstantsBloodGlucose.mgDlToMmoll
                },
                numberRow(id: "experimental.prediction.carbRatio", title: ExperimentalTexts.text("predictionCarbRatio", "Carb ratio (grams per unit)"),
                          value: defaults.experimentalPredictionCarbRatio, unit: "g", fractionDigits: 1,
                          range: ExperimentalPredictionModel.carbRatioRange, isEnabled: defaults.experimentalPredictionEnabled) { value in
                    UserDefaults.standard.experimentalPredictionCarbRatio = value
                },
                numberRow(id: "experimental.prediction.absorption", title: ExperimentalTexts.text("predictionAbsorption", "Carb absorption (grams per hour)"),
                          value: defaults.experimentalPredictionCarbAbsorption, unit: "g/h", fractionDigits: 0,
                          range: ExperimentalPredictionModel.carbAbsorptionRange, isEnabled: defaults.experimentalPredictionEnabled) { value in
                    UserDefaults.standard.experimentalPredictionCarbAbsorption = value
                }
            ]
        case .insulins:
            return [
                SettingsRow(id: "experimental.insulins.enabled", title: ExperimentalTexts.text("insulinsShow", "Show insulin activity on the chart"),
                            control: .toggle(isOn: { UserDefaults.standard.experimentalInsulinsEnabled },
                                             setIsOn: { UserDefaults.standard.experimentalInsulinsEnabled = $0 }),
                            reloadScope: .all),
                insulinRow(id: "experimental.insulins.bolus", title: ExperimentalTexts.text("insulinBolus", "Bolus insulin"),
                           choices: InsulinProfile.bolusChoices, selected: { UserDefaults.standard.experimentalBolusInsulin },
                           select: { UserDefaults.standard.experimentalBolusInsulin = $0 }),
                insulinRow(id: "experimental.insulins.basal", title: ExperimentalTexts.text("insulinBasal", "Basal insulin"),
                           choices: InsulinProfile.basalChoices, selected: { UserDefaults.standard.experimentalBasalInsulin },
                           select: { UserDefaults.standard.experimentalBasalInsulin = $0 })
            ]
        }
    }

    private func insulinRow(id: String, title: String, choices: [InsulinProfile], selected: @escaping () -> InsulinProfile,
                            select: @escaping (InsulinProfile) -> Void) -> SettingsRow {
        SettingsRow(id: id, title: title, accessory: .none,
                    control: .menuWithSelectionTitle(options: {
                        let current = selected()
                        return choices.map { SettingsMenuOption(title: $0.displayName, isSelected: $0 == current) }
                    }, selectionTitle: { selected().shortName }, selectOption: { index in
                        guard choices.indices.contains(index) else { return }
                        select(choices[index])
                    }))
    }

    private func numberRow(id: String, title: String, value: Double, unit: String, fractionDigits: Int, range: ClosedRange<Double>,
                           isEnabled: Bool, save: @escaping (Double) -> Void) -> SettingsRow {
        let text = Self.numberText(value, fractionDigits: fractionDigits)
        return SettingsRow(id: id, title: title, detail: "\(text) \(unit)", accessory: .disclosure, isEnabled: isEnabled, reloadScope: .all,
                           action: .textEntry {
                               SettingsTextEntryContent(
                                   title: title, message: String(format: ExperimentalTexts.text("numberRange", "From %@ to %@ %@."),
                                                                 Self.numberText(range.lowerBound, fractionDigits: fractionDigits),
                                                                 Self.numberText(range.upperBound, fractionDigits: fractionDigits), unit),
                                   keyboardType: .decimalPad, text: text, placeholder: nil, fieldTitle: nil, unitText: unit,
                                   actionTitle: Texts_Common.Ok, cancelTitle: Texts_Common.Cancel,
                                   action: { entered in
                                       guard let number = Self.parse(entered) else { return }
                                       save(min(max(number, range.lowerBound), range.upperBound))
                                   },
                                   cancel: nil,
                                   validator: { entered in
                                       guard let number = Self.parse(entered), range.contains(number) else {
                                           return String(format: ExperimentalTexts.text("numberRange", "From %@ to %@ %@."),
                                                         Self.numberText(range.lowerBound, fractionDigits: fractionDigits),
                                                         Self.numberText(range.upperBound, fractionDigits: fractionDigits), unit)
                                       }
                                       return nil
                                   })
                           })
    }

    /// Accepts both decimal separators.
    static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
            .flatMap { $0.isFinite ? $0 : nil }
    }

    static func numberText(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(0...fractionDigits)))
    }

    static func minutesText(_ minutes: Int) -> String {
        DateComponentsFormatter.localizedString(from: DateComponents(minute: minutes), unitsStyle: .short) ?? "\(minutes)"
    }

    func sectionTitle() -> String? {
        switch group {
        case .predictionMain, .insulins: return nil
        case .predictionModel: return ExperimentalTexts.text("predictionModel", "Model")
        }
    }

    func sectionFooter() -> String? {
        switch group {
        case .predictionMain:
            return ExperimentalTexts.text("predictionMainFooter", "Follow the trend continues the recent rise or fall that your treatments do not explain, fading over about an hour. The forecast starts only from a reading at most 15 minutes old.")
        case .predictionModel:
            return ExperimentalTexts.text("predictionModelFooter", "Insulin sensitivity: how far one unit lowers glucose. Carb ratio: grams covered by one unit. Absorption sets how long carbs take to act. Basal and premixed insulins are not part of the forecast, as in JugglucoNG.")
        case .insulins:
            return ExperimentalTexts.text("insulinsFooter", "The chart shows how fast each insulin is working, in units per hour, stacked in its own colour along the bottom. A curve ends where its source stopped measuring; nothing is extrapolated.")
        }
    }

    private func row(at index: Int) -> SettingsRow? {
        let rows = settingsRows(sectionID: 0)
        return rows.indices.contains(index) ? rows[index] : nil
    }
    func settingsRowText(index: Int) -> String { row(at: index)?.title ?? "" }
    func accessoryType(index: Int) -> SettingsAccessory { .none }
    func detailedText(index: Int) -> String? { row(at: index)?.detail }
    func numberOfRows() -> Int { settingsRows(sectionID: 0).count }
    func onRowSelect(index: Int) -> SettingsSelectedRowAction { .nothing }
    func isEnabled(index: Int) -> Bool { row(at: index)?.isEnabled ?? false }
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
}
