//
//  BgReadingsView.swift
//  xdrip
//
//  Created by Paul Plant on 10/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import SwiftUI
import OSLog

struct BgReadingsView: View {
    // MARK: - environment objects
    
    /// reference to bgReadingsAccessor
    @EnvironmentObject var bgReadingsAccessor: BgReadingsAccessor
    
    /// reference to nightscoutSyncManager
    @EnvironmentObject var nightscoutSyncManager: NightscoutSyncManager
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    // MARK: - private @State properties
    
    /// the BgReadings pulled from coredata via BgReadingsAccessor
    @State private var bgReadings: [BgReadingSnapshot] = []
    
    /// a filtered version of bgReadings to show only the values only on the selected date
    @State private var filteredBgReadings: [BgReadingSnapshot] = []
    
    /// date selected at which we should display BgReadings
    @State private var dateSelected: Date = Date()
    
    /// string holding the name of the day of the date selected
    @State private var dateSelectedDayName: String = ""
    
    // from here: https://stackoverflow.com/questions/61041209/how-to-automatically-collapse-datepicker-in-a-form-when-other-field-is-being-edi
    /// state variable to hide the datePicker when the user has selected a date
    @State private var datePickerReset = UUID()
    
    /// selection set for multi-select delete in the List
    @State private var selectedBgReadings: Set<BgReadingSnapshot> = []
    
    /// controls the visibility of the scroll-to-top button
    @State private var showScrollToTopButton = false
    
    /// used to rebuild the list at the top without wrapping it in a ScrollViewReader
    @State private var listReset = UUID()

    /// edit mode binding to enable multi-select in the List
    @Environment(\.editMode) private var editMode
    
    // MARK: - private properties
    
    /// number of days of coredata BgReadings that we should pull into the view (this will be filtered down later
    private let numberOfDaysOfBgReadingsToShow: Int = 14
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBgReadingsView)
    
    // save typing
    /// is true if the user is using mg/dL units (pulled from UserDefaults)
    private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    
    /// row index that needs to appear before the scroll-to-top button is shown
    private let scrollToTopButtonThresholdIndex = 20
    
    // MARK: - SwiftUI views
    
    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                DatePicker(selection: $dateSelected, in: Date.distantPast...latestSelectableDate, displayedComponents: .date) {
                    HStack {
                        Text(Texts_BgReadings.date)
                        Spacer()
                        Text(dateSelectedDayName)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }
                .id(self.datePickerReset)
                .onAppear { showScrollToTopButton = false }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                List(selection: $selectedBgReadings) {
                    if !filteredBgReadings.isEmpty {
                        ForEach(filteredBgReadings, id: \.self) { bgReading in
                            NavigationLink(destination: BgReadingsDetailView(bgReading: bgReading)) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(bgRangeIndicatorColor(bgRangeDescription: bgReading.bgRangeDescription()))

                                    Text(bgReading.finalValue.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).bgValueToString(mgDl: isMgDl))
                                        .foregroundColor(.primary)

                                    Text(String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
                                        .foregroundColor(.secondary)

                                    Text(bgReading.slopeArrow())
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    HStack {
                                        BackfilledReadingIndicatorDot(isVisible: bgReading.backfilledAt != nil)

                                        Text(bgReading.timeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .none))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .foregroundColor(.white)
                            }
                            .onAppear {
                                if let index = filteredBgReadings.firstIndex(of: bgReading), index >= scrollToTopButtonThresholdIndex {
                                    showScrollToTopButton = true
                                }
                            }
                        }
                        .onDelete(perform: deleteBgReading)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    } else {
                        Text(Texts_BgReadings.noReadingsToShow)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .padding(.horizontal, 16)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .id(listReset)
            .overlay(alignment: .bottomTrailing) {
                if showScrollToTopButton {
                    Button {
                        showScrollToTopButton = false
                        listReset = UUID()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.yellow)
                            .frame(width: 48, height: 48)
                            .background(Color(.secondarySystemGroupedBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showScrollToTopButton)
            .navigationTitle(Texts_BgReadings.glucoseReadingsTitle)
            .onChange(of: dateSelected, perform: { value in
                showScrollToTopButton = false

                // update the filtered array with the newly selected date
                filteredBgReadings = bgReadings.filter { Calendar.current.compare($0.timeStamp, to: dateSelected, toGranularity: .day) == .orderedSame}
                
                updateDayName(date: dateSelected)
                
                // hide the datePicker
                self.datePickerReset = UUID()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    OnlineHelpButton(topic: .glucoseReadings)

                    EditButton()
                        .tint(ConstantsAppColors.toolbarAction)

                    if !selectedBgReadings.isEmpty {
                        Button(role: .destructive) {
                            deleteSelectedBgReadings()
                        } label: {
                            Label("\(Texts_Common.delete) (\(selectedBgReadings.count))", systemImage: "trash")
                        }
                        .tint(ConstantsAppColors.toolbarDestructiveAction)
                        .accessibilityIdentifier("deleteSelectedBgReadingsButton")
                    }
                }
            }
        }
        .colorScheme(.dark)
        .onAppear() {
            initializeView()
        }
    }
    
    // MARK: - private functions
    
    /// this is called when the view appears. It will pull BG readings from coredata
    private func initializeView() {
        // set the fromDate to be midnight 'numberOfDaysOfBgReadingsToShow' days before the current date
        if let fromDate: Date = Calendar.current.date(byAdding: .day, value: -numberOfDaysOfBgReadingsToShow, to: dateSelected)?.toMidnight() {
            
            // get 'numberOfDaysOfBgReadingsToShow' days worth of BG Readings from coredata
            bgReadings = bgReadingsAccessor.getLatestBgReadingSnapshots(limit: nil, fromDate: fromDate, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: false)
            
            // create a filtered array to only show bg readings for the date selected
            filteredBgReadings = bgReadings.filter { Calendar.current.compare($0.timeStamp, to: dateSelected, toGranularity: .day) == .orderedSame}
            
            // update the day name in the user language for the newly selected date
            updateDayName(date: dateSelected)
        } else {
            // this should never happen so it's not worth localizing it
            dateSelectedDayName = "Error"
        }
    }
    
    /// delete a BG reading from the local arrays, coredata and also Nightscout based on the index passed to the function
    private func deleteBgReading(at offsets: IndexSet) {
        // as we are using a separate filtered bgReading array to populate the List in the view, we need to delete the selected index from both the primary and filtered bgReading arrays to keep them in sync. This means getting the timestamp of the filtered array and matching it to the timestamp in the main array, then deleting them both. Then we can delete it from coredata and also Nightscout
        
        // get the index to be deleted from filteredBgReadings
        let index = offsets[offsets.startIndex]
        
        // get the actual BgReading snapshot from filteredBgReadings
        let bgReadingToDelete =  filteredBgReadings[index]
        
        // get the timestamp so that we can match it to the main (unfiltered) array
        let timestampOfBgReadingToDelete = bgReadingToDelete.timeStamp
        
        // Record the user-visible deletion only after Core Data confirms that it was saved. The
        // developer message may use localized display text, while the attached Activity Log fact
        // remains typed, unit-neutral and free from arbitrary trace arguments.
        guard bgReadingsAccessor.delete(bgReadingObjectID: bgReadingToDelete.objectID) else {
            trace("failed to delete BG reading with timestamp %{public}@ from coredata", log: log, category: ConstantsLog.categoryBgReadingsView, type: .error, timestampOfBgReadingToDelete.description)
            return
        }

        trace(
            "deleted BG reading %{public}@ %{public}@ with timestamp %{public}@ from coredata",
            log: log,
            category: ConstantsLog.categoryBgReadingsView,
            type: .info,
            troubleshooting: .standard(.glucoseManagement(.deleted(
                mgDl: bgReadingToDelete.finalValue,
                measuredAt: timestampOfBgReadingToDelete
            ))),
            bgReadingToDelete.finalValue.mgDlToMmolAndToString(mgDl: isMgDl),
            String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol),
            timestampOfBgReadingToDelete.description
        )
        
        // delete from the filtered BgReading array which will also force a refresh of the view
        filteredBgReadings.remove(atOffsets: offsets)
        
        // delete from the main BgReading array using the timestamp
        bgReadings.removeAll(where: { $0.timeStamp == timestampOfBgReadingToDelete })
        
        // delete the BgReading from Nightscout (if it exists)
        nightscoutSyncManager.deleteBgReadingFromNightscout(timeStampOfBgReadingToDelete: timestampOfBgReadingToDelete)
        
        return
    }
    
    /// deletes all currently selected BG readings from the filtered list, the main list, Core Data, and Nightscout
    private func deleteSelectedBgReadings() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        
        notificationFeedback.prepare()
        
        // make a stable copy to avoid mutating the data set while iterating
        let bgReadingsToDelete = Array(selectedBgReadings)

        var readingsThatCouldNotBeDeleted = Set<BgReadingSnapshot>()

        for bgReadingToDelete in bgReadingsToDelete {
            let timestampOfBgReadingToDelete = bgReadingToDelete.timeStamp

            // Do not remove the row from the in-memory lists or claim success in either log until
            // the underlying Core Data save succeeds. This keeps the view and Activity Log honest
            // even if persistence fails part-way through a multi-selection.
            guard bgReadingsAccessor.delete(bgReadingObjectID: bgReadingToDelete.objectID) else {
                readingsThatCouldNotBeDeleted.insert(bgReadingToDelete)
                trace("failed to multi-delete BG reading with timestamp %{public}@ from coredata", log: log, category: ConstantsLog.categoryBgReadingsView, type: .error, timestampOfBgReadingToDelete.description)
                continue
            }

            trace(
                "multi-deleted BG reading %{public}@ %{public}@ with timestamp %{public}@ from coredata",
                log: log,
                category: ConstantsLog.categoryBgReadingsView,
                type: .info,
                troubleshooting: .standard(.glucoseManagement(.deleted(
                    mgDl: bgReadingToDelete.finalValue,
                    measuredAt: timestampOfBgReadingToDelete
                ))),
                bgReadingToDelete.finalValue.mgDlToMmolAndToString(mgDl: isMgDl),
                String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol),
                timestampOfBgReadingToDelete.description
            )

            // remove from filtered array (if present)
            if let indexInFiltered = filteredBgReadings.firstIndex(where: { $0.timeStamp == timestampOfBgReadingToDelete }) {
                filteredBgReadings.remove(at: indexInFiltered)
            }

            // remove from main array
            bgReadings.removeAll(where: { $0.timeStamp == timestampOfBgReadingToDelete })

            // delete from Nightscout
            nightscoutSyncManager.deleteBgReadingFromNightscout(timeStampOfBgReadingToDelete: timestampOfBgReadingToDelete)
        }
        
        notificationFeedback.notificationOccurred(readingsThatCouldNotBeDeleted.isEmpty ? .success : .error)

        // Keep only failed rows selected so the user can see which operations did not complete and
        // retry them. Exit selection mode only when the complete request succeeded.
        selectedBgReadings = readingsThatCouldNotBeDeleted
        if readingsThatCouldNotBeDeleted.isEmpty {
            editMode?.wrappedValue = .inactive
        }
    }
    
    /// Returns the colour for the small dot shown beside each glucose reading.
    /// The reading still owns the range decision, while the SwiftUI row draws the
    /// symbol rather than storing a marker inside the text.
    private func bgRangeIndicatorColor(bgRangeDescription: BgRangeDescription) -> Color {
        switch bgRangeDescription {
        case .inRange:
            return ConstantsGlucoseChart.glucoseInRangeColor
        case .notUrgent:
            return ConstantsGlucoseChart.glucoseNotUrgentRangeColor
        case .urgent:
            return ConstantsGlucoseChart.glucoseUrgentRangeColor
        }
    }
    
    /// this updates the state variable with the day name string (in user locale) based on the date passed to it
    private func updateDayName(date: Date) {
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = "EEEE"
        
        dateSelectedDayName = dateFormatter.string(from: date).capitalized
    }

    /// Last selectable timestamp for the date-only picker.
    /// This keeps tomorrow disabled without making today's selected value invalid by a few milliseconds.
    private var latestSelectableDate: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Date().toMidnight()) ?? Date()
    }
}

struct BgReadingsView_Previews: PreviewProvider {
    static var previews: some View {
        BgReadingsView()
    }
}

struct BackfilledReadingIndicatorDot: View {
    var isVisible: Bool = true

    var body: some View {
        Circle()
            .foregroundStyle(isVisible ? ConstantsUI.backfilledReadingIndicatorDotColor : .clear)
            .accessibilityLabel(Texts_BgReadings.backfilled)
            .accessibilityHidden(!isVisible)
            .frame(width: ConstantsUI.backfilledReadingIndicatorDotSize, height: ConstantsUI.backfilledReadingIndicatorDotSize)
    }
}
