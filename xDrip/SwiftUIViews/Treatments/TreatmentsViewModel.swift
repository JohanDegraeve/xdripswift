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
    @Published private(set) var showBasalFilter = UserDefaults.standard.dataFlowPolicy.showsPumpData
    @Published var datePickerReset = UUID()

    @Published private(set) var showSmallBolusTreatments = UserDefaults.standard.showSmallBolusTreatmentsInList
    @Published private(set) var showBolusTreatments = UserDefaults.standard.showBolusTreatmentsInList
    @Published private(set) var showCarbsTreatments = UserDefaults.standard.showCarbsTreatmentsInList
    @Published private(set) var showBasalTreatments = UserDefaults.standard.showBasalTreatmentsInList
    @Published private(set) var showBgCheckTreatments = UserDefaults.standard.showBgCheckTreatmentsInList
    @Published private(set) var showBasalInjectionTreatments = UserDefaults.standard.showBasalInjectionTreatmentsInList
    @Published private(set) var showNoteTreatments = UserDefaults.standard.showNoteTreatmentsInList
    @Published private(set) var selectedDate = Calendar.current.startOfDay(for: Date())

    // MARK: - private properties

    let coreDataManager: CoreDataManager
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataTreatments)

    private var allTreatments: [TreatmentSnapshot] = []
    private var lastViewedDay = Calendar.current.startOfDay(for: Date())
    private var treatmentsUpdateCounter = UserDefaults.standard.nightscoutTreatmentsUpdateCounter
    private(set) var reloadTask: Task<Void, Never>?

    // MARK: - initialization

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)

        updateDayName()
    }

    // MARK: - public functions

    /// Performs the first load, or refreshes the existing model when the tab becomes visible again.
    func initializeViewIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if lastViewedDay != today {
            // Return to today after a day change, but preserve deliberate history browsing
            // when reopening the tab or returning from the background on the same day.
            lastViewedDay = today
            selectedDateChanged(today)
            return
        }

        reloadTreatments()
    }

    /// Loads only the selected day's snapshots without making the main thread wait for SQLite.
    func reloadTreatments() {
        syncFilterSettingsFromUserDefaults()
        treatmentsUpdateCounter = UserDefaults.standard.nightscoutTreatmentsUpdateCounter
        reloadTask?.cancel()

        let fromDate = Calendar.current.startOfDay(for: selectedDate)
        guard let toDate = Calendar.current.date(byAdding: .day, value: 1, to: fromDate) else { return }
        let mainContext = coreDataManager.mainManagedObjectContext
        let context = coreDataManager.privateManagedObjectContext

        // The parent cannot see unsaved main-context edits. Retain those objects on main until
        // publication, including edits which are saved while the private fetch is waiting.
        // Only dates and snapshots cross the context boundary, never these managed objects.
        let pendingTreatments = mainContext.insertedObjects.union(mainContext.updatedObjects)
            .union(mainContext.deletedObjects).compactMap { $0 as? TreatmentEntry }

        reloadTask = Task { @MainActor [weak self] in
            do {
                try Task.checkCancellation()
                let snapshots = try await context.perform {
                    let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
                    // Use calendar midnights rather than 24 hours so clock-change days are complete.
                    // The old fetch materialised the whole history before applying this day filter.
                    request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND (treatmentdeleted == NO OR treatmentdeleted == nil)", fromDate as NSDate, toDate as NSDate)
                    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TreatmentEntry.date), ascending: false)]
                    request.returnsObjectsAsFaults = false
                    let treatments = try context.fetch(request)
                    let temporaryTreatments = treatments.filter { $0.objectID.isTemporaryID }
                    if !temporaryTreatments.isEmpty {
                        try context.obtainPermanentIDs(for: temporaryTreatments)
                    }
                    return treatments.map { TreatmentSnapshot(treatmentEntry: $0) }
                }
                // Cancelling a request does not interrupt SQLite. Discard its eventual result so
                // a slower previous day or refresh cannot overwrite the most recent selection.
                try Task.checkCancellation()
                guard let self else { return }

                let pending = Set(pendingTreatments).union(mainContext.insertedObjects.compactMap { $0 as? TreatmentEntry })
                    .union(mainContext.updatedObjects.compactMap { $0 as? TreatmentEntry })
                    .union(mainContext.deletedObjects.compactMap { $0 as? TreatmentEntry })
                let temporaryTreatments = pending.filter { !$0.isDeleted && $0.managedObjectContext != nil && $0.objectID.isTemporaryID }
                if !temporaryTreatments.isEmpty {
                    // Editors retain these IDs after the row is published. Keep the existing
                    // permanent-ID guarantee even for a local entry which has not been saved yet.
                    try mainContext.obtainPermanentIDs(for: Array(temporaryTreatments))
                }
                var treatments = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.objectID, $0) })
                for treatment in pending {
                    // Remove the parent's version first. An edit can move a treatment to another
                    // day, and an unsaved deletion must not reappear from the private snapshot.
                    treatments.removeValue(forKey: treatment.objectID)
                    if treatment.managedObjectContext != nil, !treatment.isDeleted, !treatment.treatmentdeleted,
                       treatment.date >= fromDate, treatment.date < toDate {
                        treatments[treatment.objectID] = TreatmentSnapshot(treatmentEntry: treatment)
                    }
                }
                self.allTreatments = treatments.values.sorted { $0.date > $1.date }
                self.applyFilters()
            } catch is CancellationError {
                // A newer load owns publication. Keep its data and let the old request finish.
            } catch {
                guard !Task.isCancelled, let self else { return }
                trace("failed to load treatment snapshots: %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataTreatments, type: .error, error.localizedDescription)
            }
        }
    }

    func handleUserDefaultsDidChange() {
        // Both Nightscout and CareLink already advance this counter after treatment changes.
        // Other defaults notifications only affect presentation. Fetching the whole history on
        // every notification blocked main and caused a scene update watchdog termination.
        if treatmentsUpdateCounter != UserDefaults.standard.nightscoutTreatmentsUpdateCounter {
            reloadTreatments()
        } else {
            syncFilterSettingsFromUserDefaults()
            applyFilters()
        }
    }

    func selectedDateChanged(_ newDate: Date) {
        selectedDate = Calendar.current.startOfDay(for: min(newDate, Date()))
        updateDayName()
        // Do not leave the previous day's rows visible while the selected day's query is pending.
        allTreatments = []
        applyFilters()
        reloadTreatments()
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

    func toggleBasalInjectionFilter() {
        UserDefaults.standard.showBasalInjectionTreatmentsInList.toggle()
        showBasalInjectionTreatments = UserDefaults.standard.showBasalInjectionTreatmentsInList
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

        treatmentEntry.treatmentdeleted = true
        treatmentEntry.uploaded = false

        guard coreDataManager.saveChanges() else {
            trace("failed to save a deleted treatment", log: log, category: ConstantsLog.categoryApplicationDataTreatments, type: .error)
            return
        }

        // Swipe deletion and editor deletion use the same typed fact. Emit it only after the local
        // save succeeds, and keep all treatment values, notes and identifiers in private app data.
        trace(
            "deleted treatment %{public}@ at %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataTreatments,
            type: .info,
            troubleshooting: .standard(.treatment(.deleted(
                kind: TroubleshootingTreatmentKind(treatmentEntry.treatmentType),
                treatmentAt: treatmentEntry.date
            ))),
            treatmentEntry.treatmentType.asString(),
            treatmentEntry.date.description
        )
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
        showBasalInjectionTreatments = UserDefaults.standard.showBasalInjectionTreatmentsInList
        showNoteTreatments = UserDefaults.standard.showNoteTreatmentsInList
        showBasalFilter = UserDefaults.standard.dataFlowPolicy.showsPumpData
    }

    private func applyFilters() {
        let selectedMidnight = Calendar.current.startOfDay(for: selectedDate)

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
            filteredTreatments.removeAll(where: { $0.treatmentType == .Basal || $0.treatmentType == .AutomaticBasal })
        }

        if !showBgCheckTreatments {
            filteredTreatments.removeAll(where: { $0.treatmentType == .BgCheck })
        }

        // Injection visibility is independent of both general Notes and pump basal rates.
        if !showBasalInjectionTreatments {
            filteredTreatments.removeAll(where: { $0.treatmentType == .BasalInjection })
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
        case .Insulin, .BasalInjection, .Carbs, .Exercise, .BgCheck, .Note:
            return true
        default:
            return false
        }
    }

    var iconSystemName: String {
        treatmentType.iconSystemName
    }

    var iconSize: CGFloat {
        if isSmallBolus {
            return GlucoseChartTreatmentStyle.treatmentIconSize * GlucoseChartTreatmentStyle.smallBolusScale
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
            return rawValue.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
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
            return notes
        }

        return nil
    }

    var primaryTextColor: Color {
        if date > Date() {
            return Color(.colorTertiary)
        }

        return Color(.colorPrimary)
    }

    private var isSmallBolus: Bool {
        treatmentType == .Insulin && rawValue < UserDefaults.standard.smallBolusTreatmentThreshold
    }
}

/// Shared symbols and colors for treatment rows and type selection.
extension TreatmentType {
    /// Use native symbols consistently in rows and the add/edit flow.
    func iconView(size: Double = GlucoseChartTreatmentStyle.treatmentIconSize) -> some View {
        Image(systemName: iconSystemName)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(iconColor)
    }

    var iconSystemName: String {
        switch self {
        case .Insulin:
            return GlucoseChartTreatmentStyle.bolusSymbol
        case .BasalInjection:
            return GlucoseChartTreatmentStyle.basalInjectionSymbol
        case .Carbs:
            return GlucoseChartTreatmentStyle.carbsSymbol
        case .Exercise:
            return "figure.run"
        case .BgCheck:
            return GlucoseChartTreatmentStyle.bgCheckSymbol
        case .Basal, .AutomaticBasal:
            return "chart.bar.fill"
        case .SiteChange:
            return "cross.vial.fill"
        case .SensorStart:
            return "sensor.tag.radiowaves.forward.fill"
        case .PumpBatteryChange:
            // Match the existing battery fallback because the percent-suffixed symbol requires iOS 17.
            if #available(iOS 17.0, *) {
                return "battery.100percent"
            }
            return "minus.plus.batteryblock.fill"
        case .Note:
            return GlucoseChartTreatmentStyle.noteSymbol
        }
    }

    var iconColor: Color {
        let baseColor: Color

        switch self {
        case .Insulin:
            baseColor = ConstantsGlucoseChart.bolusTreatmentColor
        case .BasalInjection:
            baseColor = ConstantsGlucoseChart.basalInjectionTreatmentColor
        case .Carbs:
            baseColor = ConstantsGlucoseChart.carbsTreatmentColor
        case .Exercise:
            baseColor = Color(red: 0.7, green: 0.25, blue: 0.85)
        case .BgCheck:
            baseColor = ConstantsGlucoseChart.bgCheckTreatmentColorInner
        case .Basal, .AutomaticBasal:
            baseColor = ConstantsGlucoseChart.basalTreatmentColor
        case .SiteChange, .SensorStart, .PumpBatteryChange:
            baseColor = .yellow
        case .Note:
            baseColor = ConstantsGlucoseChart.noteTreatmentColor
        }

        return baseColor
    }

}
