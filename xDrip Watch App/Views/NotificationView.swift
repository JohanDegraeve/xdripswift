//
//  NotificationView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 24/5/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit


struct NotificationView: View {
    var alertTitle: String?
    var bgValueAndTrend: String?
    var delta: String?
    var unit: String?
    var alertUrgencyType: AlertUrgencyType?
    var bgRangeDescriptionAsInt: Int?
    var glucoseChartImage: UIImage?
    
    var body: some View {
        
        VStack(alignment: .center, spacing: 0) {
                Text("\(alertTitle ?? "LOW ALARM")")
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(alertUrgencyType?.bannerTextColor ?? .white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -8)
                    .padding(.bottom, 8)
                    .background(alertUrgencyType?.bannerBackgroundColor ?? .black)

            HStack(alignment: .center) {
                Text("\(bgValueAndTrend ?? "123")")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(bgColor())
                
                Spacer()
                
                Text("\(delta ?? "-2")")
                    .font(.title2).fontWeight(.semibold)
                    .foregroundStyle(.colorPrimary)
            }
            .padding(.top, 4)
            .padding(.bottom, 2)
            
            if let glucoseChartImage = glucoseChartImage {
                Image(uiImage: glucoseChartImage).resizable()
                    .frame(width: ConstantsGlucoseChartSwiftUI.viewWidthNotificationWatchImage, height: ConstantsGlucoseChartSwiftUI.viewHeightNotificationWatchImage)
            }
        }
        .background(ConstantsAlerts.notificationBackgroundColor)
        .padding(.bottom, -15)
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
    
    func bgColor() -> Color {
        if let bgRangeDescriptionAsInt = bgRangeDescriptionAsInt {
            switch bgRangeDescriptionAsInt {
            case 0:
                return .green
            case 1:
                return .yellow
            default:
                return .red
            }
        }
        
        return .green
    }
    
}


#Preview {
    NotificationView()
}
