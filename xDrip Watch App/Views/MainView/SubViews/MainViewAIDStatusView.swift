//
//  MainViewAIDStatusView.swift
//  xdrip
//
//  Created by Paul Plant on 30/11/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

struct MainViewAIDStatusView: View {
    @EnvironmentObject var watchState: WatchStateModel
    
    let isSmallScreen = ConstantsAppleWatch.isSmallScreen()
    
    var body: some View {
        let textSize: CGFloat = isSmallScreen ? 14 : 16
        
        let metrics = watchState.resolvedTherapyMetrics
        HStack(alignment: .center, spacing: 0) {
            if metrics.iob.isVisible() {
                Text(watchState.aidStatusIOBString())
                    .accessibilityLabel(metrics.iob.accessibilityName(isIOB: true))
                    .accessibilityValue(watchState.aidStatusIOBString())
                Spacer()
            }
            if metrics.cob.isVisible() {
                Text(watchState.aidStatusCOBString())
                    .accessibilityLabel(metrics.cob.accessibilityName(isIOB: false))
                    .accessibilityValue(watchState.aidStatusCOBString())
                Spacer()
            }
            // Local estimates do not imply a pump or an AID operating status.
            if watchState.aidStatus != nil {
                HStack(alignment: .center, spacing: 5) {
                    Text(watchState.aidStatusActivityAgeString())
                    watchState.aidStatusIconImage()
                        .fontWeight(.bold)
                        .foregroundStyle(watchState.aidStatusColor() ?? .colorSecondary)
                }
            }
        }
        .font(.system(size: textSize))
        .fontWeight(.semibold)
        .foregroundStyle(.colorPrimary)
        .padding(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
        .background(.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 5))
        
    }
}

struct MainViewAIDStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let watchState = WatchStateModel()
        
        watchState.aidStatus = AIDStatus(condition: .active, style: .loop, statusUpdatedAt: Date().addingTimeInterval(-180), lastActivityAt: Date().addingTimeInterval(-125), iob: 2.25, cob: 24, statusTitle: "Looping", staleStatusTitle: "No data")
        
        return Group {
            MainViewAIDStatusView()
        }.environmentObject(watchState)
    }
}
