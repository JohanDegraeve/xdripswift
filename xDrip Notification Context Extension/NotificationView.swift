//
//  NotificationView.swift
//  xDrip Notification Context Extension
//
//  Created by Paul Plant on 8/6/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct NotificationView: View {
    var alertTitle: String?
    var bgReadingValues: [Double]?
    var bgReadingDates: [Date]?
    var isMgDl: Bool?
    var slopeOrdinal: Int?
    var deltaValueInUserUnit: Double?
    var urgentLowLimitInMgDl: Double?
    var lowLimitInMgDl: Double?
    var highLimitInMgDl: Double?
    var urgentHighLimitInMgDl: Double?
    var alertUrgencyType: AlertUrgencyType?
    
    var bgUnitString: String?
    var bgValueInMgDl: Double?
    var bgReadingDate: Date?
    var bgValueStringInUserChosenUnit: String?
    
    var body: some View {
        ZStack {
            Color(ConstantsAlerts.notificationBackgroundColor)
                .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: 0) {
                Text("\(alertTitle ?? "LOW ALARM")")
                    .font(.title).fontWeight(.bold)
                    .foregroundStyle(alertUrgencyType?.bannerTextColor ?? .white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(maxWidth: .infinity, maxHeight: 55)
                    .background(alertUrgencyType?.bannerBackgroundColor ?? .black)
                    .padding(.top, -15)
                
                // this is the standard widget view
                HStack(alignment: .center) {
                    Text("\(bgValueStringInUserChosenUnit ?? "")\(trendArrow())")
                        .font(.system(size: 45)).fontWeight(.bold)
                        .foregroundStyle(bgTextColor())
                        .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: -4) {
                        Text(deltaChangeStringInUserChosenUnit())
                            .font(.system(size: 30)).fontWeight(.bold)
                            .foregroundStyle(.colorPrimary)
                            .lineLimit(1)
                        
                        Text(bgUnitString ?? "")
                            .font(.system(size: 15)).fontWeight(.semibold)
                            .foregroundStyle(.colorSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                
                GlucoseChartView(glucoseChartType: .notificationExpanded, bgReadingValues: bgReadingValues, bgReadingDates: bgReadingDates, isMgDl: isMgDl ?? true, urgentLowLimitInMgDl: urgentLowLimitInMgDl ?? 60, lowLimitInMgDl: lowLimitInMgDl ?? 70, highLimitInMgDl: highLimitInMgDl ?? 180, urgentHighLimitInMgDl: urgentHighLimitInMgDl ?? 250, liveActivityType: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
            }
            .background(ConstantsAlerts.notificationBackgroundColor)
        }
    }
    
    func alertTitleColor() -> Color {
        if let alertUrgencyType = alertUrgencyType {
            switch alertUrgencyType {
            case .urgent:
                return .red
            case .warning:
                return .yellow
            default:
                return .colorPrimary
            }
        }
        
        return .colorPrimary
    }
    
    /// Blood glucose color dependant on the user defined limit values and based upon the time since the last reading
    /// - Returns: a Color either red, yellow or green
    func bgTextColor() -> Color {
        if let bgValueInMgDl = bgValueInMgDl, let urgentLowLimitInMgDl = urgentLowLimitInMgDl, let lowLimitInMgDl = lowLimitInMgDl, let highLimitInMgDl = highLimitInMgDl, let urgentHighLimitInMgDl = urgentHighLimitInMgDl {
            
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        }
        return .green
    }
    
    /// convert the optional delta change int (in mg/dL) to a formatted change value in the user chosen unit making sure all zero values are shown as a positive change to follow Nightscout convention
    /// - Returns: a string holding the formatted delta change value (i.e. +0.4 or -6)
    func deltaChangeStringInUserChosenUnit() -> String {
        if let deltaValueInUserUnit = deltaValueInUserUnit, let isMgDl = isMgDl {
            let deltaSign: String = deltaValueInUserUnit > 0 ? "+" : ""
            let deltaValueAsString = isMgDl ? deltaValueInUserUnit.mgDlToMmolAndToString(mgDl: isMgDl) : deltaValueInUserUnit.mmolToString()
            
            // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
            // show unitized zero deltas as +0 or +0.0 as per Nightscout format
            return deltaValueInUserUnit == 0.0 ? (isMgDl ? "+0" : "+0.0") : (deltaSign + deltaValueAsString)
        } else {
            return (isMgDl ?? true) ? "-" : "-.-"
        }
    }
    
    
    ///  returns a string holding the trend arrow
    /// - Returns: trend arrow string (i.e.  "↑")
    func trendArrow() -> String {
        if let slopeOrdinal = slopeOrdinal {
            switch slopeOrdinal {
            case 7:
                return "\u{2193}\u{2193}" // ↓↓
            case 6:
                return "\u{2193}" // ↓
            case 5:
                return "\u{2198}" // ↘
            case 4:
                return "\u{2192}" // →
            case 3:
                return "\u{2197}" // ↗
            case 2:
                return "\u{2191}" // ↑
            case 1:
                return "\u{2191}\u{2191}" // ↑↑
            default:
                return ""
            }
        } else {
            return ""
        }
    }
}

#Preview {
    NotificationView()
}
