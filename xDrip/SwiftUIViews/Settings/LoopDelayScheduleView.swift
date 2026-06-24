import SwiftUI

struct LoopDelayScheduleView: View {
    @Environment(\.settingsNavigationActions) private var navigationActions

    /// Maximum amount of values. If this is 5, the delay options are 0, 5, 10, 15 and 20 minutes.
    fileprivate static let maximumAmountOfValues:Int = 5
    
    /// Stores loop delay rows as minutes since midnight plus the delay value in minutes.
    @State private var loopDelays:[(Int, Int)] = [(Int, Int)]()

    /// Points to the row currently being edited. Nil means the editor is adding a new row.
    @State private var loopDelayToUpdate:Int?
    
    /// Holds the selected delay step while the pushed editor is open.
    @State private var selectedDelay:Int = 0
    
    /// Holds the selected start time while the pushed editor is open.
    @State private var selectedDate:Date = Date()
     
    var body: some View {
        List {
            ForEach(loopDelays, id: \.self.0) { loopDelay in
                SettingsStaticRowView(
                    title: loopDelay.0.convertMinutesToTimeAsString(),
                    detail: loopDelay.1.description,
                    isEnabled: true,
                    showsDisclosure: true,
                    action: { openEditor(for: loopDelay) }
                )
            }
            .onDelete(perform: delete)
        }
        .settingsListStyle(title: Texts_SettingsView.loopDelaysScreenTitle, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: openNewEditor) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear() {
            
            initializeLoopDelays()
            
        }

    }

    /// Opens the editor in add mode with the default time and delay values.
    /// The actual editor is pushed through SettingsNavigationActions so it behaves
    /// like the other SwiftUI Settings edit screens.
    private func openNewEditor() {
        loopDelayToUpdate = nil
        selectedDate = Date()
        selectedDelay = 0

        pushEditor()
    }

    /// Opens the editor for an existing loop delay row.
    /// The selected row is found by its stored start time because the list is sorted
    /// and the tuple itself is used as the row data.
    private func openEditor(for loopDelay: (Int, Int)) {
        loopDelayToUpdate = {
            for (index, entry) in loopDelays.enumerated() {
                if entry.0 == loopDelay.0 {
                    return index
                }
            }
            return nil
        }()

        guard let loopDelayToUpdate else { return }

        selectedDelay = loopDelays[loopDelayToUpdate].1 / 5
        selectedDate = Date(
            timeInterval: TimeInterval(Double(loopDelays[loopDelayToUpdate].0) * 60.0),
            since: Date().toMidnight()
        )

        pushEditor()
    }

    /// Pushes the loop delay editor and keeps the parent state as the single source
    /// of truth for saving. If the editor reports a duplicate time, it stays open
    /// and shows the warning inside the pushed screen.
    private func pushEditor() {
        let initialDate = selectedDate
        let initialDelay = selectedDelay

        navigationActions?.push(Texts_SettingsView.loopDelaysScreenTitle) { close in
            AnyView(LoopDelayEditorView(
                initialDate: initialDate,
                initialDelay: initialDelay,
                save: { date, delay in
                    selectedDate = date
                    selectedDelay = delay

                    if addOrUpdateRow() {
                        close()
                        return true
                    }

                    return false
                },
                cancel: {
                    resetStateVariables()
                }
            ))
        }
    }
    
    /// Deletes the selected loop delay row and stores the updated schedule.
    private func delete(at offsets: IndexSet) {
           
        // there should be a first element, otherwise deletion would not be possible
        guard let first = offsets.first else { return  }
        
        // only delete the first element in offsets (don't know if there can be many)
        loopDelays.remove(at: first)
        
        // store in loopDelays
        sortAndStoreLoopDelaysInUserDefaults()
        
    }
    
    /// Loads loop delays from UserDefaults once when the list first appears.
    private func initializeLoopDelays() {
        
        if loopDelays.count == 0, let storedloopDelaySchedule = UserDefaults.standard.loopDelaySchedule?.splitToInt(), let storedloopDelayValues = UserDefaults.standard.loopDelayValueInMinutes?.splitToInt() , storedloopDelaySchedule.count == storedloopDelayValues.count  {
           
            for (index, _) in storedloopDelaySchedule.enumerated() {

                loopDelays.insert((storedloopDelaySchedule[index], storedloopDelayValues[index]), at: 0)

            }
            
            loopDelays = loopDelays.sorted(by: {$0.0 < $1.0})
            
        }
        
    }
    
    /// Adds or updates the selected loop delay and returns false if the time is already used.
    private func addOrUpdateRow() -> Bool {
        
        // calculate the number of minutes since midnight
        let minutesSinceMidnight = selectedDate.minutesSinceMidNightLocalTime()
        
        // check if there's already an entry with the same value for minutes
        for (index, loopDelay) in loopDelays.enumerated() {
            
            if loopDelay.0 == minutesSinceMidnight && index != loopDelayToUpdate {
                return false
                
            }
        }


        // sort loopDelays array by minutes before leaving the function
        defer {
            
            sortAndStoreLoopDelaysInUserDefaults()
            
       }
        
        // if it's a loopdelay being updated, then update it
        if let loopDelayToUpdate = loopDelayToUpdate {
            
            loopDelays[loopDelayToUpdate].0 = minutesSinceMidnight
            loopDelays[loopDelayToUpdate].1 = selectedDelay  * 5
            
        } else {

            // create a new loopDelay and add it to loopDelays array
            loopDelays.append((minutesSinceMidnight, selectedDelay * 5))

        }
        
        resetStateVariables()
        return true
        
    }
    
    /// Sorts the rows and stores the two UserDefaults strings expected by the loop logic.
    private func sortAndStoreLoopDelaysInUserDefaults() {
        
        loopDelays = loopDelays.sorted(by: {$0.0 < $1.0})

        // store loopDelays in UserDefaults

        var scheduleToStore: String?
        var delaysToStore: String?
        
        for loopDelay in loopDelays {
            
            if scheduleToStore == nil {
                
                scheduleToStore = loopDelay.0.description
                delaysToStore = loopDelay.1.description
                
            } else {
                
                scheduleToStore = scheduleToStore! + "-" + loopDelay.0.description
                delaysToStore = delaysToStore! + "-" + loopDelay.1.description
 
            }
            
        }
        
        UserDefaults.standard.loopDelaySchedule = scheduleToStore
        UserDefaults.standard.loopDelayValueInMinutes = delaysToStore
        
    }
    
    /// Clears temporary editor state after save or cancel.
    private func resetStateVariables() {
        loopDelayToUpdate =  nil

        selectedDate = Date()
        
        selectedDelay = 0
    }
    
}

private struct LoopDelayEditorView: View {
    @State private var selectedDate: Date
    @State private var selectedDelay: Int
    @State private var duplicateLoopDelayAlertIsPresented = false
    @State private var didComplete = false

    let save: (Date, Int) -> Bool
    let cancel: () -> Void

    /// Starts the pushed loop delay editor with the values selected by the parent list.
    init(
        initialDate: Date,
        initialDelay: Int,
        save: @escaping (Date, Int) -> Bool,
        cancel: @escaping () -> Void
    ) {
        _selectedDate = State(initialValue: initialDate)
        _selectedDelay = State(initialValue: initialDelay)
        self.save = save
        self.cancel = cancel
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Label hidden", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            } header: {
                Text(Texts_SettingsView.selectTime)
            } footer: {
                Text(Texts_SettingsView.expanatoryTextSelectTime)
            }

            Section {
                Picker("Label hidden", selection: $selectedDelay) {
                    ForEach((0...(LoopDelayScheduleView.maximumAmountOfValues - 1)), id: \.self) {
                        Text("\($0 * 5)")
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                Text(Texts_SettingsView.selectValue)
            } footer: {
                Text(Texts_SettingsView.expanatoryTextSelectValue)
            }
        }
        .settingsListStyle(title: Texts_SettingsView.loopDelaysScreenTitle, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Texts_Common.Ok) {
                    didComplete = true

                    if save(selectedDate, selectedDelay) {
                    } else {
                        didComplete = false
                        duplicateLoopDelayAlertIsPresented = true
                    }
                }
            }
        }
        .onDisappear {
            guard !didComplete else { return }

            cancel()
        }
        .alert(isPresented: $duplicateLoopDelayAlertIsPresented) {
            Alert(
                title: Text(Texts_SettingsView.warningLoopDelayAlreadyExists),
                dismissButton: .default(Text(Texts_Common.Ok))
            )
        }
    }
}

struct LoopDelayScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        LoopDelayScheduleView()
    }
}
