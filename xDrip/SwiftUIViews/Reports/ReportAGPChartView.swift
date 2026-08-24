//
//  ReportAGPChartView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Renders the AGP chart used inside the generated report.
struct GlucoseReportAGPChartView: View {
    let points: [GlucoseReportAGPPoint]
    let usesMgDl: Bool
    let language: GlucoseReportLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle(language.text(.ambulatoryGlucoseProfile))
                Spacer()
                legend
            }

            // The shared marks keep screen and report calculations aligned while this presentation
            // retains the report's print palette, axis position and compact typography.
            AGPChartView(
                points: points,
                usesMgDl: usesMgDl,
                presentation: .printableReport,
                emptyMessage: language.text(.insufficientAGPData)
            )
            .frame(height: 205)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem(color: GlucoseReportColors.agpOuterLine, title: "5-95%")
            legendItem(color: GlucoseReportColors.agpInnerLine, title: "25-75%")
            legendItem(color: GlucoseReportColors.clinicalBlue, title: "Median")
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 4)
            Text(title)
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.secondaryText)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GlucoseReportColors.clinicalBlue)
    }

}
