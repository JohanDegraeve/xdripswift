//
//  CareLinkPresentation.swift
//  xdripswift
//
//  Created by Paul Plant on 3/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

extension CareLinkConnectionStatus {
    /// Uses one connection palette on Home, Settings and the pump status screen.
    var indicatorColor: Color {
        switch self {
        case .loginRequired, .selectPatient: return .gray
        case .connecting, .noData: return ConstantsAppColors.warning
        case .active: return ConstantsAppColors.normal
        case .stale, .rateLimited: return .orange
        case .error: return ConstantsAppColors.urgent
        }
    }
}
