//
//  NovoPenDoseImporter.swift
//  xdrip
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//
//  Saves the doses of one NovoPen read as treatments, once each. The air-shot rule ports
//  opennov SaveCompleted.isPrimingDose.
//

import CoreData
import Foundation
import OSLog

enum NovoPenPenKind: String {
    case bolus, basal
}

/// Imported rows keep an empty Nightscout id and `uploaded == false`, so the normal Nightscout sync exports them.
final class NovoPenDoseImporter {
    static let enteredBy = "xDrip4iOS NovoPen"

    struct SaveFailed: Error {}

    private let coreDataManager: CoreDataManager
    private let defaults: UserDefaults
    private let now: () -> Date
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNovoPen)

    init(coreDataManager: CoreDataManager, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.coreDataManager = coreDataManager
        self.defaults = defaults
        self.now = now
    }

    struct Outcome: Equatable {
        /// Rows created.
        let created: Int
        /// Small newest doses held back as possible air shots until a later scan decides.
        let heldBack: Int
    }

    /// A row without an identifier (from Nightscout, after a reinstall or on another phone) is this dose if it is this close.
    static let matchTolerance: TimeInterval = 60

    /// A dose already stored, even one the user deleted, is never created again.
    @MainActor
    func importDoses(_ result: NovoPenReadResult, kind: NovoPenPenKind) throws -> Outcome {
        let now = now()
        let leftOut = defaults.novoPenIgnoreAirShots
            ? Self.airShotRelativeTimes(result.doses, maxUnits: defaults.novoPenAirShotMaxUnits,
                                        window: defaults.novoPenAirShotWindowMinutes * 60, now: now)
            : (ignored: [], heldBack: [])
        let oldest = now.addingTimeInterval(-NovoPenSession.importWindow)
        let doses = result.doses.filter { !leftOut.ignored.contains($0.relativeTime) && !leftOut.heldBack.contains($0.relativeTime) && $0.date >= oldest }

        let context = coreDataManager.privateChildManagedObjectContext()
        let (created, matched) = try context.performAndWait { () throws -> (Int, Int) in
            let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
            // Deleted rows included: a dose the user deleted must not come back.
            request.predicate = NSPredicate(format: "penDoseIdentifier IN %@", doses.map { $0.identifier(serial: result.serial) })
            var known = Set(try context.fetch(request).compactMap(\.penDoseIdentifier))
            let matched = try Self.matchRowsWithoutIdentifier(doses.filter { !known.contains($0.identifier(serial: result.serial)) },
                                                              result: result, kind: kind, since: oldest, known: &known, context: context)
            var created = 0
            for dose in doses {
                let identifier = dose.identifier(serial: result.serial)
                guard known.insert(identifier).inserted else { continue }
                let content = Self.content(for: dose, result: result, kind: kind)
                let row = TreatmentEntry(date: dose.date, value: content.value, valueSecondary: 0, treatmentType: content.type, nightscoutEventType: nil,
                                         enteredBy: Self.enteredBy, notes: content.notes, nsManagedObjectContext: context)
                row.treatmentdeleted = false
                row.penDoseIdentifier = identifier
                created += 1
            }
            if context.hasChanges { try context.save() }
            return (created, matched)
        }

        trace("NovoPen: %{public}@ created %{public}d treatments, matched %{public}d stored without identifier, %{public}d air shots left out, %{public}d held back", log: log,
              category: ConstantsLog.categoryNovoPen, type: .info, result.serial, created, matched, leftOut.ignored.count, leftOut.heldBack.count)
        let outcome = Outcome(created: created, heldBack: leftOut.heldBack.count)
        guard created + matched > 0 else { return outcome }
        guard coreDataManager.saveChangesSynchronously() else { throw SaveFailed() }
        guard created > 0 else { return outcome }
        defaults.nightscoutTreatmentsUpdateCounter += 1
        if defaults.dataFlowPolicy.exportsTreatmentsToNightscout {
            defaults.nightscoutSyncRequired = true
        }
        return outcome
    }

    /// Rows downloaded from Nightscout carry no `penDoseIdentifier`. A pen row without one, of the same type and value
    /// and within `matchTolerance`, is taken to be the dose, and gets its identifier. One row per dose, closest first,
    /// so two equal doses close together are not merged. Returns the number of rows matched.
    private static func matchRowsWithoutIdentifier(_ doses: [NovoPenDoseRecord], result: NovoPenReadResult, kind: NovoPenPenKind,
                                                   since oldest: Date, known: inout Set<String>, context: NSManagedObjectContext) throws -> Int {
        guard !doses.isEmpty else { return 0 }
        let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
        // Deleted rows included, as above.
        request.predicate = NSPredicate(format: "penDoseIdentifier == nil AND enteredBy == %@ AND date >= %@",
                                        enteredBy, oldest.addingTimeInterval(-matchTolerance) as NSDate)
        let rows = try context.fetch(request)
        let pairs = doses.flatMap { dose -> [(dose: NovoPenDoseRecord, row: TreatmentEntry, distance: TimeInterval)] in
            let content = content(for: dose, result: result, kind: kind)
            return rows.compactMap { row in
                let distance = abs(row.date.timeIntervalSince(dose.date))
                guard distance <= matchTolerance, row.treatmentType == content.type, abs(row.value - content.value) < 0.001,
                      content.type != .Note || row.notes == content.notes else { return nil }
                return (dose, row, distance)
            }
        }.sorted { $0.distance < $1.distance }
        var matched = 0
        for pair in pairs where pair.row.penDoseIdentifier == nil {
            let identifier = pair.dose.identifier(serial: result.serial)
            guard known.insert(identifier).inserted else { continue }
            pair.row.penDoseIdentifier = identifier
            matched += 1
        }
        return matched
    }

    /// The type, value and notes of the row a dose becomes.
    private static func content(for dose: NovoPenDoseRecord, result: NovoPenReadResult, kind: NovoPenPenKind) -> (type: TreatmentType, value: Double, notes: String) {
        switch kind {
        case .bolus:
            return (.Insulin, dose.units, result.model.isEmpty ? "PEN \(result.serial)" : "PEN \(result.serial) \(result.model)")
        case .basal:
            let description = "NovoPen \(result.serial)"
            if BasalInjectionPayload(units: dose.units, insulinDescription: description) != nil {
                return (.BasalInjection, dose.units, description)
            }
            // BasalInjectionPayload takes whole units only. Keep the dose readable, and out of bolus IOB.
            // Not localized on purpose: matchRowsWithoutIdentifier compares these notes, and Nightscout shows them as is.
            return (.Note, 0, "Basal injection: \(description), \(dose.units) U")
        }
    }

    /// Doses to leave out of this scan: air shots (`ignored`), and candidates whose window has not passed yet (`heldBack`).
    /// An air shot is a dose of at most `maxUnits` followed by another dose within `window`, unless an
    /// earlier air shot lies within `window` before it (opennov SaveCompleted.isPrimingDose).
    /// A candidate is such a small dose with no later dose that is less than `window` old: a later scan decides.
    /// A candidate is always held back, even right after an air shot.
    static func airShotRelativeTimes(_ doses: [NovoPenDoseRecord], maxUnits: Double, window: TimeInterval, now: Date) -> (ignored: Set<UInt32>, heldBack: Set<UInt32>) {
        let sorted = doses.sorted { $0.date < $1.date }
        var airShots = Set<UInt32>()
        var candidates = Set<UInt32>()
        var lastAirShot: Date?
        for (index, dose) in sorted.enumerated() where dose.units <= maxUnits {
            // Every record has units > 0, so the nearest later dose decides.
            let next = sorted[(index + 1)...].first { $0.date > dose.date }
            if next == nil && dose.date > now.addingTimeInterval(-window) {
                candidates.insert(dose.relativeTime)   // the newest dose, nothing after it to check
                continue
            }
            if let lastAirShot, dose.date.timeIntervalSince(lastAirShot) < window { continue }
            if let next, next.date.timeIntervalSince(dose.date) < window {
                airShots.insert(dose.relativeTime)
                lastAirShot = dose.date
            }
        }
        return (airShots, candidates)
    }
}
