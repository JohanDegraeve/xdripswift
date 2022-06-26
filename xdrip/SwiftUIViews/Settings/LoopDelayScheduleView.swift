import SwiftUI

struct LoopDelayScheduleView: View {

    /// maximum amount of values, if 5, then possible delay values to choose form will be 0, 5, 10, 15, 20
    private static let maximumAmountOfValues:Int = 5
    
    /// will store two arrays, one with loopdelayschedules (timestamps between 00:00 at 23:59 in minutes), one with loopdelayvalues in minutes
    @State private var loopDelays:[(Int, Int)] = [(Int, Int)]()

    /// state variable, if true then view is shown to add a new row or updating an existing row
    @State private var addMode = false
    
    /// index in loopDelays, points to loopDelay being updated. Used to update a loopDelay. If nil then user is adding a new loopDelay, if  not nil then user is updating a loopDelay
    ///
    /// add @State property wrapper because the value is changed
    @State private var loopDelayToUpdate:Int?
    
    /// used in sheet that allows to add or update a loop delay row : delay selected
    @State private var selectedDelay:Int = 0
    
    /// used in DatePicker to add or update a loop delay row - this is the timestamp
    @State private var selectedDate:Date = Date()
    
    /// state variable to control display of alert
    @State private var duplicateLoopDelayAlertIsPresented = false
    
    /// used in conjunction with duplicateLoopDelayAlertIsPresented
    ///
    /// setting duplicateLoopDelayAlertIsPresented to true while the add sheet is being presented, doesn't show the alert. Seems solution is as described here https://stackoverflow.com/questions/63968344/swiftui-how-to-show-an-alert-after-a-sheet-is-closed, which is to show the alert when the sheet is dismissed
    @State private var showLoopDelayAlertOnDismiss = false
    
    init() {
        
        // setup colors etc.
        setupView()
        
    }
     
    var body: some View {

        NavigationView {
            
            List {

                ForEach(loopDelays, id: \.self.0) { loopDelay in
                    
                    HStack {
                        
                        // example 320 is converted to 05:20
                        Text(loopDelay.0.convertMinutesToTimeAsString())
                        
                        Spacer()
                        
                        Text(loopDelay.1.description)
                        
                    }
                    
                    .contentShape(Rectangle()) //to ensure onTapGesture works also on the Spacer in the HStack, see https://www.hackingwithswift.com/quick-start/swiftui/how-to-control-the-tappable-area-of-a-view-using-contentshape
                    
                    .onTapGesture {
                        
                        // find index of loopDelay that is clicked, and assign to loopDelayToUpdate
                        loopDelayToUpdate = {
                            for (index, entry) in loopDelays.enumerated() {
                                if entry.0 == loopDelay.0 {
                                    return index
                                }
                            }
                            return nil
                        }()
                        
                        // loopDelayToUpdate should not be nil, otherwise there's a coding error
                        guard let loopDelayToUpdate = loopDelayToUpdate else {return}
                            
                        selectedDelay = loopDelays[loopDelayToUpdate].1 / 5
                        
                        let nowAt000 = Date().toMidnight()

                        selectedDate = Date(timeInterval: TimeInterval(Double(loopDelays[loopDelayToUpdate].0) * 60.0), since: nowAt000)
                        
                        // show the sheet that allows to udpate
                        addMode = true
                        
                    }
                    
                }

                // to delete rows
                .onDelete(perform: delete)
                
            }
            
            // Open the sheet to add a new row, when clicking the plus
            .navigationBarItems(trailing: Button(action: {addMode = true}) { Image(systemName: "plus").foregroundColor(ConstantsUI.plusButtonColor) })

            // sheet to add a new row
            .sheet(isPresented: $addMode, onDismiss: {
                
                if showLoopDelayAlertOnDismiss {
                    
                    showLoopDelayAlertOnDismiss = false
                    
                    // add a small delay before setting duplicateLoopDelayAlertIsPresented to true, as explained here https://stackoverflow.com/a/71638878
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        duplicateLoopDelayAlertIsPresented = true
                    }
                    
                }
            }, content: {
                
                Form {
                    
                    Section(header: Text(Texts_SettingsView.selectTime)
                                .foregroundColor(ConstantsUI.sectionHeaderColor),
                            
                            footer: Text(Texts_SettingsView.expanatoryTextSelectTime)
                                .foregroundColor(ConstantsUI.sectionFooterColor)) {

                                    DatePicker("Label hidden", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                    
                    }

                    Section(header: Text(Texts_SettingsView.selectValue)
                                .foregroundColor(ConstantsUI.sectionHeaderColor),
                            
                            footer: Text(Texts_SettingsView.expanatoryTextSelectValue)
                                .foregroundColor(ConstantsUI.sectionFooterColor)) {
                                    
                                    Picker("Label hidden", selection: $selectedDelay) {
                                        ForEach((0...(LoopDelayScheduleView.maximumAmountOfValues - 1)), id: \.self) {
                                            Text("\($0*5)")
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    
                    }

                    HStack(alignment: VerticalAlignment.center, spacing: nil) {

                        Button(action: {
                            resetStateVariables()
                        }, label: {
                            Text(Texts_Common.Cancel)
                                .foregroundColor(ConstantsUI.dismissOrCancelColor)
                        })
                        .buttonStyle(BorderlessButtonStyle())

                        Spacer()

                        Button(action: {
                            addOrUpdateRow()
                        }, label: {
                            Text(Texts_Common.Ok)
                        })
                        .buttonStyle(BorderlessButtonStyle())

                    }
                    
                }
                
            })
          
            .alert(isPresented: $duplicateLoopDelayAlertIsPresented, content: {
                
                // after dismissing the alert, then reopen the sheet
                Alert(title: Text(Texts_SettingsView.warningLoopDelayAlreadyExists), dismissButton: .default(Text(Texts_Common.Ok)) {
                    
                    // add a small delay before setting to true, as explained here https://stackoverflow.com/a/71638878
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        addMode = true
                    }
                   
                })
                
            })

        }
        .onAppear() {
            
            // initialize loopDelays
            initializeLoopDelays()
            
        }

    }
    
    private func delete(at offsets: IndexSet) {
           
        // there should be a first element, otherwise deletion would not be possible
        guard let first = offsets.first else { return  }
        
        // only delete the first element in offsets (don't know if there can be many)
        loopDelays.remove(at: first)
        
    }
    
    /// intialize the state variable loopDelays based on contents in UserDefaults
    private func initializeLoopDelays() {
        
        if loopDelays.count == 0, let storedloopDelaySchedule = UserDefaults.standard.loopDelaySchedule?.splitToInt(), let storedloopDelayValues = UserDefaults.standard.loopDelayValueInMinutes?.splitToInt() , storedloopDelaySchedule.count == storedloopDelayValues.count  {
           
            for (index, _) in storedloopDelaySchedule.enumerated() {

                loopDelays.insert((storedloopDelaySchedule[index], storedloopDelayValues[index]), at: 0)

            }
            
            loopDelays = loopDelays.sorted(by: {$0.0 < $1.0})
            
        }
        
    }
    
    /// setup colors etc.
    private func setupView() {
        
        // background color
        UITableView.appearance().backgroundColor = ConstantsUI.listBackGroundUIColor
        
    }
    
    /// update loopDelays based on State variables selectedDate and selectedDelay
    private func addOrUpdateRow() {
        
        // calculate the number of minutes since midnight
        let minutesSinceMidnight = selectedDate.minutesSinceMidNightLocalTime()
        
        // check if there's already an entry with the same value for minutes
        for (index, loopDelay) in loopDelays.enumerated() {
            
            if loopDelay.0 == minutesSinceMidnight && index != loopDelayToUpdate {
                showLoopDelayAlertOnDismiss = true
                addMode = false
                return
                
            }
        }


        // sort loopDelays array by minutes before leaving the function
        // and remove the sheet that allows to create/update a scheduled entry
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
        
    }
    
    /// sort loopDelays array, and store current values of loopDelays in both UserDefaults.standard.loopDelaySchedule and UserDefaults.standard.loopDelayValueInMinutes
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
    
    /// reset addMode to false, selectedDate to now, selectedDelay to 0, loopDelayToUpdate to nil
    private func resetStateVariables() {
        
        addMode = false
        
        loopDelayToUpdate =  nil

        selectedDate = Date()
        
        selectedDelay = 0
    }
    
}

struct LoopDelayScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        LoopDelayScheduleView()
    }
}
