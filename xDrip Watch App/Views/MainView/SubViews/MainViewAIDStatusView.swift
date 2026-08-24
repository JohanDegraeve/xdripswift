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
        
        HStack(alignment: .center, spacing: 0) {
            Text(watchState.aidStatusIOBString())
                .font(.system(size: textSize))
                .fontWeight(.semibold)
                .foregroundStyle(.colorPrimary)
            
            Spacer()
            
            // CareLink sends meal entries but no active-carb/COB calculation. The shared semantic
            // capability keeps the unavailable placeholder out of both Watch and iOS compact rows.
            if watchState.aidStatus?.supportsCOB == true {
                Text(watchState.aidStatusCOBString())
                    .font(.system(size: textSize))
                    .fontWeight(.semibold)
                    .foregroundStyle(.colorPrimary)

                Spacer()
            }
            
            HStack(alignment: .center, spacing: 5) {
                Text(watchState.aidStatusActivityAgeString())
                    .font(.system(size: textSize))
                    .fontWeight(.semibold)
                    .foregroundStyle(.colorPrimary)

                watchState.aidStatusIconImage()
                    .font(.system(size: textSize))
                    .fontWeight(.bold)
                    .foregroundStyle(watchState.aidStatusColor() ?? .colorSecondary)
            }
        }
        //        .padding(.leading, isSmallScreen ? 6 : 8)
        //        .padding(.trailing, isSmallScreen ? 6 : 8)
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
