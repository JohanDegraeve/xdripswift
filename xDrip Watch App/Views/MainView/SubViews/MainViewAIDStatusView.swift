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
    
    let isSmallScreen = WKInterfaceDevice.current().screenBounds.size.width < ConstantsAppleWatch.pixelWidthLimitForSmallScreen ? true : false
    
    var body: some View {
        let textSize: CGFloat = isSmallScreen ? 14 : 16
        
        HStack(alignment: .center, spacing: 0) {
            Text("\(watchState.deviceStatusIOB.round(toDecimalPlaces: 2).stringWithoutTrailingZeroes)U")
                .font(.system(size: textSize))
                .fontWeight(.semibold)
                .foregroundStyle(.colorPrimary)
            
            Spacer()
            
            Text("\(watchState.deviceStatusCOB.round(toDecimalPlaces: 0).stringWithoutTrailingZeroes)g")
                .font(.system(size: textSize))
                .fontWeight(.semibold)
                .foregroundStyle(.colorPrimary)
            
            Spacer()
            
            HStack(alignment: .center, spacing: 5) {
                watchState.deviceStatusIconImage()
                    .font(.system(size: textSize))
                    .fontWeight(.bold)
                    .foregroundStyle(watchState.deviceStatusColor() ?? .colorSecondary)
                
                Text(watchState.deviceStatusLastLoopDateTimeAgoString)
                    .font(.system(size: textSize))
                    .fontWeight(.semibold)
                    .foregroundStyle(.colorPrimary)
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
        
        watchState.deviceStatusIOB = 2.25
        watchState.deviceStatusCOB = 24
        watchState.deviceStatusCreatedAt = Date().addingTimeInterval(-180)
        watchState.deviceStatusLastLoopDate = Date().addingTimeInterval(-125)
        
        return Group {
            MainViewAIDStatusView()
        }.environmentObject(watchState)
    }
}
