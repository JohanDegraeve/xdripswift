//
//  TreatmentsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI
import CoreData
import OSLog

/// Loads treatment snapshots and applies the selected day and persisted filters.
///
/// Core Data objects are converted to value snapshots before publication so the SwiftUI list does
/// not retain managed objects while rows are filtered, edited or deleted.
@MainActor final class TreatmentsViewModel: ObservableObject {
    // MARK: - @Published properties

    @Published private(set) var filteredTreatments: [TreatmentSnapshot] = []
    @Published private(set) var selectedDateDayName = ""
    @Published private(set) var showBasalFilter = UserDefaults.standard.nightscoutFollowType != .none
    @Published var datePickerReset = UUID()

    @Published private(set) var showSmallBolusTreatments = UserDefaults.standard.showSmallBolusTreatmentsInList
    @Published private(set) var showBolusTreatments = UserDefaults.standard.showBolusTreatmentsInList
    @Published private(set) var showCarbsTreatments = UserDefaults.standard.showCarbsTreatmentsInList
    @Published private(set) var showBasalTreatments = UserDefaults.standard.showBasalTreatmentsInList
    @Published private(set) var showBgCheckTreatments = UserDefaults.standard.showBgCheckTreatmentsInList
    @Published private(set) var showNoteTreatments = UserDefaults.standard.showNoteTreatmentsInList
    @Published private(set) var selectedDate = Date().toMidnight()

    // MARK: - private properties

    let coreDataManager: CoreDataManager
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataTreatments)

    private var allTreatments: [TreatmentSnapshot] = []
    private var didInitializeView = false

    // MARK: - initialization

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)

        updateDayName()
    }

    // MARK: - public functions

    /// Performs the first load, or refreshes the existing model when the tab becomes visible again.
    func initializeViewIfNeeded() {
        if didInitializeView {
            reloadTreatments()
            return
        }

        didInitializeView = true
        reloadTreatments()
    }

    /// Reloads the treatment history and reapplies the current filters.
    func reloadTreatments() {
        syncFilterSettingsFromUserDefaults()

        allTreatments = treatmentEntryAccessor
            .getLatestTreatments(howOld: nil)
            .filter { !$0.treatmentdeleted }
            .sorted(by: { $0.date > $1.date })
            .map { TreatmentSnapshot(treatmentEntry: $0) }

        applyFilters()
    }

    func handleUserDefaultsDidChange() {
        reloadTreatments()
    }

    func selectedDateChanged(_ newDate: Date) {
        selectedDate = min(newDate, Date()).toMidnight()
        updateDayName()
        applyFilters()
        datePickerReset = UUID()
    }

    func toggleSmallBolusFilter() {
        guard showBolusTreatments else {
            return
        }

        UserDefaults.standard.showSmallBolusTreatmentsInList.toggle()
        showSmallBolusTreatments = UserDefaults.standard.showSmallBolusTreatmentsInList
        applyFilters()
    }

    func toggleBolusFilter() {
        UserDefaults.standard.showBolusTreatmentsInList.toggle()
        showBolusTreatments = UserDefaults.standard.showBolusTreatmentsInList
        applyFilters()
    }

    func toggleCarbsFilter() {
        UserDefaults.standard.showCarbsTreatmentsInList.toggle()
        showCarbsTreatments = UserDefaults.standard.showCarbsTreatmentsInList
        applyFilters()
    }

    func toggleBasalFilter() {
        UserDefaults.standard.showBasalTreatmentsInList.toggle()
        showBasalTreatments = UserDefaults.standard.showBasalTreatmentsInList
        applyFilters()
    }

    func toggleBgCheckFilter() {
        UserDefaults.standard.showBgCheckTreatmentsInList.toggle()
        showBgCheckTreatments = UserDefaults.standard.showBgCheckTreatmentsInList
        applyFilters()
    }

    func toggleNoteFilter() {
        UserDefaults.standard.showNoteTreatmentsInList.toggle()
        showNoteTreatments = UserDefaults.standard.showNoteTreatmentsInList
        applyFilters()
    }

    func deleteTreatment(_ treatment: TreatmentSnapshot) {
        guard let treatmentEntry = treatmentEntryAccessor.getTreatment(objectID: treatment.objectID) else {
            return
        }

        trace(
            "deleting treatment %{public}@ at %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataTreatments,
            type: .info,
            treatmentEntry.treatmentType.asString(),
            treatmentEntry.date.description
        )

        treatmentEntry.treatmentdeleted = true
        treatmentEntry.uploaded = false

        coreDataManager.saveChanges()
        setNightscoutSyncRequiredToTrue()
        reloadTreatments()
    }

    // MARK: - private functions

    private func syncFilterSettingsFromUserDefaults() {
        showSmallBolusTreatments = UserDefaults.standard.showSmallBolusTreatmentsInList
        showBolusTreatments = UserDefaults.standard.showBolusTreatmentsInList
        showCarbsTreatments = UserDefaults.standard.showCarbsTreatmentsInList
        showBasalTreatments = UserDefaults.standard.showBasalTreatmentsInList
        showBgCheckTreatments = UserDefaults.standard.showBgCheckTreatmentsInList
        showNoteTreatments = UserDefaults.standard.showNoteTreatmentsInList
        showBasalFilter = UserDefaults.standard.nightscoutFollowType != .none
    }

    private func applyFilters() {
        let selectedMidnight = selectedDate.toMidnight()

        filteredTreatments = allTreatments.filter { treatment in
            Calendar.current.compare(treatment.date, to: selectedMidnight, toGranularity: .day) == .orderedSame
        }

        if !showBolusTreatments {
            filteredTreatments.removeAll(where: { $0.treatmentType == .Insulin })
        } else if !showSmallBolusTreatments {
            filteredTreatments.removeAll {
                $0.treatmentType == .Insulin && $0.rawValue < UserDefaults.standard.smallBolusTreatmentThreshold
            }
        }

        if !showCarbsTreatments {
            filteredTreatments.removeAll(where: { $0.treatmentType == .Carbs })
        }

        if !showBasalTreatments {
            filteredTreatments.removeAll(where: { $0.treatmentType == .Basal })
        }

        if !showBgCheckTreatments {
            filteredTreatments.removeAll(where: { $0.treatmentType == .BgCheck })
        }

        if !showNoteTreatments {
            filteredTreatments.removeAll(where: { $0.treatmentType == .Note })
        }
    }

    private func updateDayName() {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "EEEE"

        selectedDateDayName = dateFormatter.string(from: selectedDate).capitalized
    }

    private func setNightscoutSyncRequiredToTrue() {
        let latestSyncRequestDate = UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? Date.distantPast

        if latestSyncRequestDate.timeIntervalSinceNow <
            -ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }
    }
}

enum TreatmentEditorState: Identifiable {
    case add
    case edit(TreatmentSnapshot)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let treatment):
            return treatment.objectID.uriRepresentation().absoluteString
        }
    }
}

/// Immutable treatment data used by list rows and the treatment editor route.
struct TreatmentSnapshot: Hashable {
    let objectID: NSManagedObjectID
    let date: Date
    let treatmentType: TreatmentType
    let rawValue: Double
    let valueSecondary: Double
    let enteredBy: String?
    let notes: String?

    init(treatmentEntry: TreatmentEntry) {
        objectID = treatmentEntry.objectID
        date = treatmentEntry.date
        treatmentType = treatmentEntry.treatmentType
        rawValue = treatmentEntry.value
        valueSecondary = treatmentEntry.valueSecondary
        enteredBy = treatmentEntry.enteredBy
        notes = treatmentEntry.notes
    }

    var isEditable: Bool {
        switch treatmentType {
        case .Insulin, .Carbs, .Exercise, .BgCheck, .Note:
            return true
        default:
            return false
        }
    }

    var iconSystemName: String {
        switch treatmentType {
        case .Insulin:
            return "arrowtriangle.down.fill"
        case .Carbs:
            return "circle.fill"
        case .Exercise:
            return "heart.fill"
        case .BgCheck:
            return "drop.fill"
        case .Basal:
            return "chart.bar.fill"
        case .SiteChange:
            return "cross.vial.fill"
        case .SensorStart:
            return "sensor.tag.radiowaves.forward.fill"
        case .PumpBatteryChange:
            return "battery.100percent"
        case .Note:
            return "note.text"
        }
    }

    var iconColor: Color {
        let baseColor: Color

        switch treatmentType {
        case .Insulin:
            baseColor = ConstantsGlucoseChart.bolusTreatmentColor
        case .Carbs:
            baseColor = ConstantsGlucoseChart.carbsTreatmentColor
        case .Exercise:
            baseColor = Color(red: 1, green: 0, blue: 1)
        case .BgCheck:
            baseColor = ConstantsGlucoseChart.bgCheckTreatmentColorInner
        case .Basal:
            baseColor = ConstantsGlucoseChart.basalTreatmentColor
        case .SiteChange, .SensorStart, .PumpBatteryChange:
            baseColor = .yellow
        case .Note:
            baseColor = ConstantsGlucoseChart.noteTreatmentColor
        }

        return date > Date() ? baseColor.opacity(0.5) : baseColor
    }

    var iconSize: CGFloat {
        if isSmallBolus {
            return 11
        }

        if treatmentType == .BgCheck {
            return 15
        }

        if treatmentType == .Note {
            return 14
        }

        return 13
    }

    var typeText: String {
        treatmentType.asString()
    }

    var timeString: String {
        date.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
    }

    var valueText: String? {
        switch treatmentType {
        case .BgCheck:
            return rawValue.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                .bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                .stringWithoutTrailingZeroes
        case .SiteChange, .SensorStart, .PumpBatteryChange, .Note:
            return nil
        default:
            return (round(rawValue * 100) / 100).stringWithoutTrailingZeroes
        }
    }

    var unitText: String? {
        switch treatmentType {
        case .SiteChange, .SensorStart, .PumpBatteryChange, .Note:
            return nil
        default:
            return treatmentType.unit()
        }
    }

    var secondaryText: String? {
        if treatmentType == .Basal {
            return "\(Int(valueSecondary))\(Texts_Common.minuteshort)"
        }

        if treatmentType == .Note {
            return notePreviewText
        }

        return nil
    }

    var primaryTextColor: Color {
        if date > Date() {
            return Color(.colorTertiary)
        }

        return Color(.colorPrimary)
    }

    var secondaryTextColor: Color {
        Color(.colorTertiary)
    }

    private var isSmallBolus: Bool {
        treatmentType == .Insulin && rawValue < UserDefaults.standard.smallBolusTreatmentThreshold
    }

    private var notePreviewText: String? {
        guard let notes else {
            return nil
        }

        guard notes.hasPrefix(ConstantsNightscout.postProcessingNotePrefix) else {
            return notes
        }

        return String(notes.dropFirst(ConstantsNightscout.postProcessingNotePrefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .toNilIfLength0()
    }
}
