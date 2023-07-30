//
//  TextsBgReadings.swift
//  xdrip
//
//  Created by Paul Plant on 24/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// all texts related to bg reading views
enum Texts_BgReadings {
    static private let filename = "BgReadings"
    
    static let glucoseReadingsTitle:String = {
        return NSLocalizedString("glucoseReadingsTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Readings", comment: "glucose reading")
    }()

    static let glucoseReadingTitle:String = {
        return NSLocalizedString("glucoseReadingTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Reading", comment: "glucose reading")
    }()

    static let selectDate:String = {
        return NSLocalizedString("selectDate", tableName: filename, bundle: Bundle.main, value: "Date", comment: "which date should be selected")
    }()
    
    static let noReadingsToShow:String = {
        return NSLocalizedString("noReadingsToShow", tableName: filename, bundle: Bundle.main, value: "No readings to show", comment: "no readings are found for the selected date")
    }()
    
    static let generalSectionHeader:String = {
        return NSLocalizedString("generalSectionHeader", tableName: filename, bundle: Bundle.main, value: "General", comment: "general glucose reading section header")
    }()
    
    static let internalDataSectionHeader:String = {
        return NSLocalizedString("internalDataSectionHeader", tableName: filename, bundle: Bundle.main, value: "Internal Data", comment: "internal glucose reading data")
    }()
    
    static let timestamp:String = {
        return NSLocalizedString("timestamp", tableName: filename, bundle: Bundle.main, value: "Timestamp", comment: "timestamp of glucose reading")
    }()
    
    static let calculatedValue:String = {
        return NSLocalizedString("calculatedValue", tableName: filename, bundle: Bundle.main, value: "Calculated Value", comment: "calculated value of the glucose readings")
    }()
    
    static let slopeArrow:String = {
        return NSLocalizedString("slopeArrow", tableName: filename, bundle: Bundle.main, value: "Slope Arrow", comment: "the slope arrow of the glucose reading")
    }()
    
    static let id:String = {
        return NSLocalizedString("id", tableName: filename, bundle: Bundle.main, value: "ID", comment: "id of the glucose reading")
    }()
    
    static let deviceName:String = {
        return NSLocalizedString("deviceName", tableName: filename, bundle: Bundle.main, value: "Device Name", comment: "device name of the transmitter used to send the glucose reading")
    }()
    
    static let rawData:String = {
        return NSLocalizedString("rawData", tableName: filename, bundle: Bundle.main, value: "Raw Data", comment: "the raw data value of the glucose reading")
    }()
    
}



