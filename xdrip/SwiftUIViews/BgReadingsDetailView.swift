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
            
            Section(header: Text("General")) {
                
                row(title: "Time", data: bgReading.timeStamp.toStringInUserLocale(timeStyle: .long, dateStyle: .long))
                
                row(title: "Calculated Value", data: bgReading.calculatedValue.mgdlToMmol(mgdl: isMgDl).bgValueRounded(mgdl: isMgDl).stringWithoutTrailingZeroes + " " + String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
                
                row(title: "Slope Arrow", data: bgReading.slopeArrow())
                
            }
            
            Section(header: Text("Internal Data")) {
                
                row(title: "ID", data: bgReading.id.description)
                
                row(title: "Device Name", data: bgReading.deviceName?.description ?? nilString)
                
                row(title: "Raw Data", data: bgReading.rawData.stringWithoutTrailingZeroes)
                
                row(title: "Calibration Flag", data: bgReading.calibrationFlag.description)
                
                // enabled below for testing. Will probably remove before final release
                row(title: "a", data: bgReading.a == 0.0 ? nilString : bgReading.a.description)
                
                row(title: "b", data: bgReading.b == 0.0 ? nilString : bgReading.b.description)
                
                row(title: "c", data: bgReading.c == 0.0 ? nilString : bgReading.c.description)
                
                row(title: "ra", data: bgReading.ra == 0.0 ? nilString : bgReading.ra.description)
                
                row(title: "rb", data: bgReading.rb == 0.0 ? nilString : bgReading.rb.description)
                
                row(title: "rc", data: bgReading.rc == 0.0 ? nilString : bgReading.rc.description)
                
            }
            
        }
        .navigationTitle("Glucose Reading")
        
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
