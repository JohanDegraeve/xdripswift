//
//  BgReadingsDetailView.swift
//  
//
//  Created by Paul Plant on 20/7/23.
//

import SwiftUI

struct BgReadingsDetailView: View {
    
    /// this must be passed in by the parent view
    let bgReading: BgReading
    
    // MARK: - private properties
    
    /// a common string to show in case a BgReading property is nil
    private let nilString = "-"
    
    /// is true if the user is using mg/dL units (pulled from UserDefaults)
    private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    
    // MARK: - SwiftUI views
    
    var body: some View {
        
        List {
            
            Section(header: Text(Texts_BgReadings.generalSectionHeader)) {
                
                row(title: Texts_BgReadings.timestamp, data: bgReading.timeStamp.toStringInUserLocale(timeStyle: .long, dateStyle: .long))
                
                row(title: "", data: bgReading.timeStamp.formatted(date: .omitted, time: .complete))
                
                row(title: Texts_BgReadings.calculatedValue, data: bgReading.calculatedValue.mgdlToMmol(mgdl: isMgDl).bgValueRounded(mgdl: isMgDl).bgValuetoString(mgdl: isMgDl) + " " + String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
                
                row(title: Texts_BgReadings.slopeArrow, data: bgReading.slopeArrow())
                
            }
            
            Section(header: Text(Texts_BgReadings.internalDataSectionHeader)) {
                
                row(title: Texts_BgReadings.id, data: bgReading.id.description)
                
                row(title: Texts_BgReadings.deviceName, data: bgReading.deviceName?.description ?? nilString)
                
                row(title: Texts_BgReadings.rawData, data: bgReading.rawData.stringWithoutTrailingZeroes)
                
            }
            
        }
        .navigationTitle(Texts_BgReadings.glucoseReadingTitle)
        
    }
    
    // MARK: - private functions
    
    /// returns a row view so that all rows are the same
    /// - parameters:
    ///   - title: the title text
    ///   - data: the value text
    /// - returns:
    ///   - a view with the formatted row inside it
    private func row(title: String, data: String) -> AnyView {
        
        // wrap the HStack in an AnyView so that it can be returned back to the caller
        let rowView = AnyView(HStack {
            
            Text(title)
            
            Spacer()
            
            Text(data)
                .foregroundColor(.secondary)
            
        })
     
        return rowView
        
    }
    
}
