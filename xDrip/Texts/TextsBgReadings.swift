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

    static let glucoseReadingTitle: String = {
        return NSLocalizedString("glucoseReadingTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Reading", comment: "glucose reading")
    }()

    static let date: String = {
        return NSLocalizedString("date", tableName: filename, bundle: Bundle.main, value: "Date", comment: "which date should be selected")
    }()
    
    static let noReadingsToShow: String = {
        return NSLocalizedString("noReadingsToShow", tableName: filename, bundle: Bundle.main, value: "No readings to show", comment: "no readings are found for the selected date")
    }()

    static let generalSectionHeader: String = {
        return NSLocalizedString("generalSectionHeader", tableName: filename, bundle: Bundle.main, value: "General", comment: "general glucose reading section header")
    }()
    
    static let slopeSectionHeader: String = {
        return NSLocalizedString("slopeSectionHeader", tableName: filename, bundle: Bundle.main, value: "Slope", comment: "glucose reading slope header")
    }()
    
    static let internalDataSectionHeader: String = {
        return NSLocalizedString("internalDataSectionHeader", tableName: filename, bundle: Bundle.main, value: "Internal Data", comment: "internal glucose reading data")
    }()

    static let glucoseValueSectionHeader: String = {
        return NSLocalizedString("glucoseValueSectionHeader", tableName: filename, bundle: Bundle.main, value: "Glucose Value", comment: "glucose value processing section header")
    }()
    
    static let timestamp: String = {
        return NSLocalizedString("timestamp", tableName: filename, bundle: Bundle.main, value: "Timestamp", comment: "timestamp of glucose reading")
    }()

    static let backfilled: String = {
        return NSLocalizedString("backfilled", tableName: filename, bundle: Bundle.main, value: "Backfilled", comment: "accessibility label for a glucose reading that was added from backfill")
    }()

    static let backfilledAtFooterFormat: String = {
        return NSLocalizedString("backfilledAtFooterFormat", tableName: filename, bundle: Bundle.main, value: "Backfilled %@", comment: "footer text explaining when a glucose reading was backfilled")
    }()
    
    static let calculatedValue: String = {
        return NSLocalizedString("calculatedValue", tableName: filename, bundle: Bundle.main, value: "Calculated Value", comment: "calculated value of the glucose readings")
    }()

    static let calibratedValue: String = {
        return NSLocalizedString("calibratedValue", tableName: filename, bundle: Bundle.main, value: "Calibrated Value", comment: "calibrated value of the glucose reading")
    }()

    static let finalGlucose: String = {
        return NSLocalizedString("finalGlucose", tableName: filename, bundle: Bundle.main, value: "Glucose Value", comment: "final glucose value after post processing")
    }()

    static let glucoseRange: String = {
        return NSLocalizedString("glucoseRange", tableName: filename, bundle: Bundle.main, value: "Glucose Range", comment: "glucose range row title")
    }()

    static let bgRangeUrgent: String = {
        return NSLocalizedString("bgRangeUrgent", tableName: filename, bundle: Bundle.main, value: "Urgent", comment: "urgent glucose range description")
    }()

    static let bgRangeNotUrgent: String = {
        return NSLocalizedString("bgRangeNotUrgent", tableName: filename, bundle: Bundle.main, value: "Not Urgent", comment: "not urgent glucose range description")
    }()

    static let bgRangeInRange: String = {
        return NSLocalizedString("bgRangeInRange", tableName: filename, bundle: Bundle.main, value: "In Range", comment: "in range glucose range description")
    }()
    
    static let slopeArrow: String = {
        return NSLocalizedString("slopeArrow", tableName: filename, bundle: Bundle.main, value: "Slope Arrow", comment: "the slope arrow of the glucose reading")
    }()
    
    static let slopePerMinute: String = {
        return NSLocalizedString("slopePerMinute", tableName: filename, bundle: Bundle.main, value: "Slope/minute", comment: "the slope value of the glucose reading per minute")
    }()
    
    static let slopePer5Minutes: String = {
        return NSLocalizedString("slopePer5Minutes", tableName: filename, bundle: Bundle.main, value: "Slope/5 minutes", comment: "the slope value of the glucose reading per 5 minutes")
    }()
    
    static let id:String = {
        return NSLocalizedString("id", tableName: filename, bundle: Bundle.main, value: "ID", comment: "id of the glucose reading")
    }()
    
    static let deviceName: String = {
        return NSLocalizedString("deviceName", tableName: filename, bundle: Bundle.main, value: "Device", comment: "device name of the transmitter used to send the glucose reading")
    }()
    
    static let rawData: String = {
        return NSLocalizedString("rawData", tableName: filename, bundle: Bundle.main, value: "Raw Data", comment: "the raw data value of the glucose reading")
    }()

    static let rawValue: String = {
        return NSLocalizedString("rawValue", tableName: filename, bundle: Bundle.main, value: "Raw Value", comment: "raw glucose value of the glucose reading")
    }()

    static let adjustedValue: String = {
        return NSLocalizedString("adjustedValue", tableName: filename, bundle: Bundle.main, value: "Adjusted Value", comment: "adjusted glucose value of the glucose reading")
    }()

    static let smoothedValue: String = {
        return NSLocalizedString("smoothedValue", tableName: filename, bundle: Bundle.main, value: "Smoothed Value", comment: "smoothed glucose value of the glucose reading")
    }()

    static let finalValue: String = {
        return NSLocalizedString("finalValue", tableName: filename, bundle: Bundle.main, value: "Final Value", comment: "final stored glucose value of the glucose reading")
    }()
    
    static let calibrationTitle: String = {
        return NSLocalizedString("calibrationTitle", tableName: filename, bundle: Bundle.main, value: "Calibration Applied", comment: "the calibration applied to the glucose reading")
    }()
    
    static let slope: String = {
        return NSLocalizedString("slope", tableName: filename, bundle: Bundle.main, value: "Slope", comment: "the slope applied to the calibration")
    }()
    
    static let intercept: String = {
        return NSLocalizedString("intercept", tableName: filename, bundle: Bundle.main, value: "Intercept", comment: "the intercept applied to the calibration")
    }()
    
    static let calibrationValue: String = {
        return NSLocalizedString("calibrationValue", tableName: filename, bundle: Bundle.main, value: "Calibration Value", comment: "the calibration value applied to the calibration")
    }()
    
    static let sensorRawValue: String = {
        return NSLocalizedString("sensorRawValue", tableName: filename, bundle: Bundle.main, value: "Sensor Raw Value", comment: "the raw value to which the calibration was applied")
    }()
    
}
