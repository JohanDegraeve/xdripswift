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
    
    /// reference to nightscoutUploadManager
    @EnvironmentObject var nightScoutUploadManager: NightScoutUploadManager
    
    // MARK: - private @State properties
    
    /// the BgReadings pulled from coredata via BgReadingsAccessor
    @State private var bgReadings: [(BgReading)] = [(BgReading)]()
    
    /// a filtered version of bgReadings to show only the values only on the selected date
    @State private var filteredBgReadings: [(BgReading)] = [(BgReading)]()
    
    /// date selected at which we should display BgReadings
    @State private var dateSelected: Date = Date()
    
    /// string holding the name of the day of the date selected
    @State private var dateSelectedDayName: String = ""
    
    // from here: https://stackoverflow.com/questions/61041209/how-to-automatically-collapse-datepicker-in-a-form-when-other-field-is-being-edi
    /// state variable to hide the datePicker when the user has selected a date
    @State private var datePickerReset = UUID()
    
    // MARK: - private properties
    
    /// number of days of coredata BgReadings that we should pull into the view (this will be filtered down later
    private let numberOfDaysOfBgReadingsToShow: Int = 14
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBgReadingsView)
    
    // save typing
    /// is true if the user is using mg/dL units (pulled from UserDefaults)
    private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    
    // MARK: - SwiftUI views
    
    var body: some View {
        
        NavigationView {
            
            VStack {
                
                DatePicker(selection: $dateSelected, in: Date().addingTimeInterval(-(Double(numberOfDaysOfBgReadingsToShow) * 24 * 3600))...Date(), displayedComponents: .date) {
                    
                    HStack {
                        
                        Text("Date")
                        
                        Spacer()
                        
                        Text(dateSelectedDayName)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                    }
                    
                }
                .padding()
                .padding(.horizontal)
                .padding(.bottom, 0)
                .id(self.datePickerReset)
                
                List {
                    
                    // only process the view contents if there is data to show.
                    if !filteredBgReadings.isEmpty {
                        
                        ForEach(filteredBgReadings, id: \.self) { bgReading in
                            NavigationLink(destination: BgReadingsDetailView(bgReading: bgReading)) {
                                
                                HStack {
                                    
                                    visualIndicator(bgRangeDescription: bgReading.bgRangeDescription())
                                        .font(.system(size: 10))
                                    
                                    Text(bgReading.calculatedValue.mgdlToMmol(mgdl: isMgDl).bgValueRounded(mgdl: isMgDl).stringWithoutTrailingZeroes)
                                        .foregroundColor(.primary)
                                    
                                    Text(String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
                                        .foregroundColor(.secondary)
                                    
                                    Text(bgReading.slopeArrow())
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(bgReading.timeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .none))
                                        .foregroundColor(.secondary)
                                    
                                }
                                .foregroundColor(.white)
                                
                            }
                            
                        }
                        .onDelete(perform: deleteBgReading)
                        
                    }
                    
                    else {
                        
                        // this is shown when there is no data for the selected date
                        Text("No readings to show...")
                        
                    }
                    
                }
                
            }
            .navigationTitle("Glucose Readings")
            .onChange(of: dateSelected, perform: { value in
                filteredBgReadings = bgReadings.filter { Calendar.current.compare($0.timeStamp, to: dateSelected, toGranularity: .day) == .orderedSame}
                updateDayName(date: dateSelected)
                self.datePickerReset = UUID()
            })
            
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
            bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: fromDate, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: false)
            
            // create a filtered array to only show bg readings for the date selected
            filteredBgReadings = bgReadings.filter { Calendar.current.compare($0.timeStamp, to: dateSelected, toGranularity: .day) == .orderedSame}
            
            // update the day name in the user language for the newly selected date
            updateDayName(date: dateSelected)
            
        } else {
            
            // this should never happen
            dateSelected = "Error"
            
        }
        
    }
    
    
    /// delete a BG reading from the local arrays, coredata and also Nightscout based on the index passed to the function
    private func deleteBgReading(at offsets: IndexSet) {
        
        // as we are using a separate filtered bgReading array to populate the List in the view, we need to delete the selected index from both the primary and filtered bgReading arrays to keep them in sync. This means getting the timestamp of the filtered array and matching it to the timestamp in the main array, then deleting them both. Then we can delete it from coredata and also Nightscout
        
        // get the index to be deleted from filteredBgReadings
        let index = offsets[offsets.startIndex]
        
        // get the actual BgReading from filteredBgReadings
        let bgReadingToDelete =  filteredBgReadings[index]
        
        // get the timestamp so that we can match it to the main (unfiltered) array
        let timestampOfBgReadingToDelete = bgReadingToDelete.timeStamp
        
        trace("deleting BG reading %{public}@ %{public}@ with timestamp %{public}@ from coredata", log: log, category: ConstantsLog.categoryBgReadingsView, type: .info, bgReadingToDelete.calculatedValue.mgdlToMmol(mgdl: isMgDl).bgValueRounded(mgdl: isMgDl).stringWithoutTrailingZeroes, String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol), timestampOfBgReadingToDelete.description)
        
        // delete from the filtered BgReading array which will also force a refresh of the view
        filteredBgReadings.remove(atOffsets: offsets)
        
        // delete from the main BgReading array using the timestamp
        bgReadings.removeAll(where: { $0.timeStamp == timestampOfBgReadingToDelete })
        
        // delete the BgReading from coredata
        bgReadingsAccessor.delete(bgReading: bgReadingToDelete)
        
        // delete the BgReading from Nightscout (if it exists)
        nightScoutUploadManager.deleteBgReadingFromNightscout(timeStampOfBgReadingToDelete: timestampOfBgReadingToDelete)
        
        return
        
    }
    
    /// returns the visual indicator symbol based on the BgRangeDescription from a BgReading
    /// - parameters:
    ///   - bgRangeDescription: an enum as defined in ConstantsWatch
    /// - returns:
    ///   - a Text view containing a string (in this case a coloured symbol)
    private func visualIndicator(bgRangeDescription: BgRangeDescription) -> Text {
        
        var visualIndicator = ""
        
        // configure the indicator based on the relevant range colour/symbol
        // copied from WatchManager.createCalendarEvent()
        switch bgRangeDescription {
        case .inRange:
            visualIndicator = ConstantsWatch.visualIndicatorInRange
        case .notUrgent:
            visualIndicator = ConstantsWatch.visualIndicatorNotUrgent
        case .urgent:
            visualIndicator = ConstantsWatch.visualIndicatorUrgent
        }
        
        // return the indicator symbol
        return Text(visualIndicator)
        
    }
    
    /// this updates the state variable with the day name string (in user locale) based on the date passed to it
    private func updateDayName(date: Date) {
        
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = "EEEE"
        
        dateSelectedDayName = dateFormatter.string(from: date)
        
    }
}

struct BgReadingsView_Previews: PreviewProvider {
    static var previews: some View {
        BgReadingsView()
    }
}

/*
 
 
 struct BgReadingsView: View {
     
     // MARK: - private properties
     
     /// reference to bgReadingsAccessor
     @EnvironmentObject var bgReadingsAccessor: BgReadingsAccessor
     
     /// reference to nightscoutUploadManager
     @EnvironmentObject var nightScoutUploadManager: NightScoutUploadManager
     
     /// coreDataManager to be used throughout the project
     @EnvironmentObject var coreDataManager: CoreDataManager
     
     /// the BG Readings pulled from coredata via BgReadingsAccessor
     @State private var bgReadings: [(BgReading)] = [(BgReading)]()
     
     /// a local array of BG Readings values with useful formatting
     @State private var bgReadingsArray: [(timeStamp: Date, timeStampString: String, calculatedValue: Double, slopeArrow: String, bgRangeDescription: BgRangeDescription)] = [(Date, String, Double, String, BgRangeDescription)]()
     
     @State private var isRemoveBgReadingAlertPresented = false
     
     @State private var deleteBgReadingAlert = false
     
     /// number of days of coredata BG Readings that we should pull into the view
     private let numberOfDaysInResults: Int = 2
     
     // save typing
     private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
     
     var body: some View {
             
         NavigationStack {
             
             List {
                 
                 // only process the view contents if there is data to show.
                 if !bgReadingsArray.isEmpty {
                     
                     ForEach(bgReadingsArray, id: \.self.0) { bgReading in
                         
                         HStack {
                                 
                             visualIndicator(bgRangeDescription: bgReading.bgRangeDescription)
                                 .font(.system(size: 10))
                                 
                             Text(bgReading.calculatedValue.mgdlToMmol(mgdl: isMgDl).bgValueRounded(mgdl: isMgDl).stringWithoutTrailingZeroes)
                             
                             Text(String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
                                 .foregroundColor(.gray)
                             
                             Text(bgReading.slopeArrow)
                                 .fontWeight(.bold)
                             
                             Spacer()
                             
                             Text(bgReading.timeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short))
                                 .foregroundColor(.gray)
                             
                         }
                         .foregroundColor(.white)
                         
                     }
                     .onDelete(perform: deleteBgReading)
                     
                 }
                 
                 else {
                     
                     Text("No readings to show...")
                     
                 }
                 
             }
             .navigationTitle("Glucose Readings")
             .foregroundColor(.white)
             //.navigationBarTitleDisplayMode(.automatic)
             
         }
         .colorScheme(.dark)
         .onAppear() {
             
             initializeBGReadingsView()
             
         }
         
     }
     
     /// this is called when the view appears. It will initialise the UI state variables from UserDefaults, pull BG readings from coredata and then format/store these in a local array for display
     private func initializeBGReadingsView() {
                 
         // get 'numberOfDaysInResults' days worth of BG Readings from coredata
         bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: numberOfDaysInResults, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: false)
         
         // make sure that bgReadingsArray is empty
         //bgReadingsArray = []
         
         for bgReading in bgReadings {
             
             bgReadingsArray.append((bgReading.timeStamp, bgReading.timeStamp.toMidnight().description, bgReading.calculatedValue, bgReading.slopeArrow(), bgReading.bgRangeDescription()))
             
         }
         
     }
     
     private func deleteBgReading(at offsets: IndexSet) {
         
         // get the timestamp of the index to be deleted
         let index = offsets[offsets.startIndex]
         
         // delete from the local BG array
         bgReadingsArray.remove(atOffsets: offsets)
         
         // get the timestamp from the local BG array at the index that we want to delete
         let timeStampOfBgReadingToDelete = bgReadingsArray[index].timeStamp
         
         // retrieve the BgReading from coredata that coincides with this timestamp
         let bgReadingToDelete = bgReadingsAccessor.getBgReadingFromTimeStamp(timeStamp: timeStampOfBgReadingToDelete)!
         
         // delete the BgReading from coredata
         bgReadingsAccessor.delete(bgReading: bgReadingToDelete)
         
         // delete it from Nightscout (if it exists)
         nightScoutUploadManager.deleteBgReadingFromNightscout(timeStampOfBgReadingToDelete: timeStampOfBgReadingToDelete)
         
         return
     }
     
     
     private func visualIndicator(bgRangeDescription: BgRangeDescription) -> Text {
         
         var visualIndicator = ""
     
         // get the current range of the last reading then
         // configure the indicator based on the relevant range
         switch bgRangeDescription {
         case .inRange:
             visualIndicator = ConstantsWatch.visualIndicatorInRange
         case .notUrgent:
             visualIndicator = ConstantsWatch.visualIndicatorNotUrgent
         case .urgent:
             visualIndicator = ConstantsWatch.visualIndicatorUrgent
         }
         
         // pre-append the indicator to the title
         return Text(visualIndicator)
         
     }
     
 }
 
 */
