import os
import Foundation
import SwiftUI

fileprivate enum Setting:Int, CaseIterable {
    
    ///should readings be spoken or not
    case speakBgReadings = 0
    
    /// language to use
    case speakBgReadingLanguage = 1
    
    ///should trend be spoken or not
    case speakTrend = 2
    
    /// should delta be spoken or not
    case speakDelta = 3
    
    /// speak each reading, each 2 readings ...  integer value
    case speakInterval = 4
    
}

/// conforms to SettingsViewModelProtocol for all speak settings in the first sections screen
class SettingsViewSpeakSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel)
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [
            nativeSettingsRow(id: "speak.speakBgReadings", index: Setting.speakBgReadings.rawValue, sectionID: sectionID),
            nativeSettingsRow(
                id: "speak.speakBgReadingLanguage",
                index: Setting.speakBgReadingLanguage.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            ),
            nativeSettingsRow(
                id: "speak.speakTrend",
                index: Setting.speakTrend.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            ),
            nativeSettingsRow(
                id: "speak.speakDelta",
                index: Setting.speakDelta.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            ),
            nativeSettingsRow(
                id: "speak.speakInterval",
                index: Setting.speakInterval.rawValue,
                sectionID: sectionID,
                isVisible: UserDefaults.standard.speakReadings
            )
        ]
    }

    /// Keep the saved schedule visible when the master switch is off. Only its controls are disabled.
    static func scheduleSection() -> SettingsSection {
        let status = speechStatus()
        return SettingsSection(
            title: Texts_SettingsView.speakScheduleSection,
            footer: Texts_SettingsView.speakScheduleExplanation,
            rows: [
                SettingsRow(
                    id: "speak.schedule",
                    title: Texts_SettingsView.enableSchedule,
                    control: .toggle(
                        isOn: { UserDefaults.standard.speakReadingsScheduleEnabled },
                        setIsOn: { UserDefaults.standard.speakReadingsScheduleEnabled = $0 }
                    ),
                    isEnabled: UserDefaults.standard.speakReadings
                ),
                SettingsRow(
                    id: "speak.schedule.start",
                    title: Texts_SettingsView.speakScheduleStart,
                    control: .custom(content: { AnyView(SpeakScheduleTimeRow(isStart: true)) }),
                    isEnabled: UserDefaults.standard.speakReadings,
                    isVisible: UserDefaults.standard.speakReadingsScheduleEnabled
                ),
                SettingsRow(
                    id: "speak.schedule.end",
                    title: Texts_SettingsView.speakScheduleEnd,
                    control: .custom(content: { AnyView(SpeakScheduleTimeRow(isStart: false)) }),
                    isEnabled: UserDefaults.standard.speakReadings,
                    isVisible: UserDefaults.standard.speakReadingsScheduleEnabled
                ),
                SettingsRow(
                    id: "speak.schedule.status",
                    title: Texts_HomeView.statusActionTitle,
                    detail: status.text,
                    detailColor: status.color,
                    detailIndicator: SettingsIndicator(color: status.color),
                    accessory: .none
                )
            ]
        )
    }

    /// Use the speech check for both status indicators so the displayed state matches the schedule.
    /// A disabled master switch is gray here and red on the parent row. Yellow means the master
    /// is enabled but the current time is outside the schedule; it does not indicate an error.
    static func speechStatus(isParent: Bool = false) -> (text: String, color: Color) {
        guard UserDefaults.standard.speakReadings else {
            return (Texts_Common.disabled, isParent ? ConstantsAppColors.urgent : ConstantsAppColors.disabledText)
        }
        return UserDefaults.standard.shouldSpeakReadings()
            ? (Texts_SettingsView.speakScheduleActive, ConstantsAppColors.normal)
            : (Texts_SettingsView.speakScheduleInactive, .yellow)
    }

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
   func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return .nothing
        case .speakTrend:
            return .nothing
        case .speakDelta:
            return .nothing
        case .speakInterval:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_SpeakIntervalTitle, message: Texts_SettingsView.settingsviews_SpeakIntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.speakInterval.description, placeHolder: "0", fieldTitle: Texts_Common.enterValue, unitText: Texts_Common.minutes, actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.speakInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)
        case .speakBgReadingLanguage:
            
            //find index for languageCode type currently stored in userdefaults
            var selectedRow:Int?
            if let languageCode = UserDefaults.standard.speakReadingLanguageCode {
                selectedRow = ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.codes.firstIndex(of:languageCode)
            } else {
                selectedRow = ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.codes.firstIndex(of:Texts_SpeakReading.defaultLanguageCode)
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.speakReadingLanguageSelection, data: ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.names, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.speakReadingLanguageCode = ConstantsSpeakReadingLanguages.allLanguageNamesAndCodes.codes[index]
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)

        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleSpeak
    }

    func numberOfRows() -> Int {
        if !UserDefaults.standard.speakReadings {
            return 1
        }
        else {
            return Setting.allCases.count
        }
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return Texts_SettingsView.labelSpeakBgReadings
        case .speakBgReadingLanguage:
            return Texts_SettingsView.labelSpeakLanguage
        case .speakTrend:
            return Texts_SettingsView.labelSpeakTrend
        case .speakDelta:
            return Texts_SettingsView.labelSpeakDelta
        case .speakInterval:
            return Texts_SettingsView.settingsviews_SpeakIntervalTitle
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return SettingsAccessory.none
        case .speakTrend:
            return SettingsAccessory.none
        case .speakDelta:
            return SettingsAccessory.none
        case .speakInterval:
            return SettingsAccessory.disclosure
        case .speakBgReadingLanguage:
            return SettingsAccessory.disclosure
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .speakBgReadings:
            return nil
        case .speakTrend:
            return nil
        case .speakDelta:
            return nil
        case .speakInterval:
            return UserDefaults.standard.speakInterval.description + " " + Texts_Common.minutes
        case .speakBgReadingLanguage:
            return Texts_SpeakReading.languageName
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .speakBgReadings:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.speakReadings },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("speakBgReadings changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.speakReadings = isOn
                }
            )
        case .speakTrend:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.speakTrend },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("speakTrend changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.speakTrend = isOn
                }
            )
        case .speakDelta:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.speakDelta },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("speakDelta changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewSpeakSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.speakDelta = isOn
                }
            )
        case .speakInterval, .speakBgReadingLanguage:
            return nil
        }
    }
}

/// A compact time picker for one end of the daily window. Both rows observe the same stored
/// minutes so validation always uses the other row's latest value, including external changes.
private struct SpeakScheduleTimeRow: View {
    let isStart: Bool
    @Environment(\.isEnabled) private var isEnabled
    @AppStorage(UserDefaults.Key.speakReadingsStartMinute.rawValue) private var startMinute = 9 * 60
    @AppStorage(UserDefaults.Key.speakReadingsEndMinute.rawValue) private var endMinute = 22 * 60
    @State private var showEqualTimes = false

    var body: some View {
        DatePicker(
            isStart ? Texts_SettingsView.speakScheduleStart : Texts_SettingsView.speakScheduleEnd,
            selection: Binding(
                get: {
                    let minute = isStart ? startMinute : endMinute
                    // The date is only a picker carrier. Use a fixed day rather than today so
                    // a daylight-saving transition does not normalize an otherwise valid time.
                    return Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 15, hour: minute / 60, minute: minute % 60)) ?? Date()
                },
                set: { date in
                    let calendar = Calendar.current
                    let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
                    guard minute != (isStart ? endMinute : startMinute) else {
                        showEqualTimes = true
                        return
                    }
                    if isStart { startMinute = minute } else { endMinute = minute }
                }
            ),
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.compact)
        .foregroundStyle(isEnabled ? ConstantsAppColors.rowTitleText : ConstantsAppColors.disabledText)
        .alert(Texts_SettingsView.speakScheduleDifferentTimes, isPresented: $showEqualTimes) {
            Button(Texts_Common.Ok, role: .cancel) {}
        }
    }
}

/// Observe all speech preferences so Settings, quick actions, and App Intents update the same UI.
/// Attach this to the List to preserve its native sections. Clock updates run only while speech
/// and scheduling are enabled and the screen is active; SwiftUI cancels the task on disappearance.
struct SpeakReadingsSettingsRefresh: ViewModifier {
    let isRelevant: Bool
    let refresh: () -> Void
    @AppStorage(UserDefaults.Key.speakReadings.rawValue) private var enabled = false
    @AppStorage(UserDefaults.Key.speakReadingsScheduleEnabled.rawValue) private var scheduled = false
    @AppStorage(UserDefaults.Key.speakReadingsStartMinute.rawValue) private var start = 9 * 60
    @AppStorage(UserDefaults.Key.speakReadingsEndMinute.rawValue) private var end = 22 * 60
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: [enabled ? 1 : 0, scheduled ? 1 : 0, start, end]) { _ in
                if isRelevant { refresh() }
            }
            .task(id: scenePhase == .active && enabled && scheduled) { @MainActor in
                guard isRelevant else { return }
                // Recheck on appearance or a change of execution state. Only a running schedule
                // needs minute-boundary updates; preference changes are handled above.
                refresh()
                guard scenePhase == .active, enabled, scheduled else { return }
                while !Task.isCancelled {
                    let delay = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch { return }
                    guard !Task.isCancelled else { return }
                    refresh()
                }
            }
    }
}
