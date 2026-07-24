//
//  ReportTimeInRangeBarView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct GlucoseReportTimeInRangeBarView: View {
    let distribution: GlucoseReportRangeDistribution
    let title: String
    let buckets: [GlucoseReportRangeBucket]
    let usesMgDl: Bool
    let sourceText: String
    let sourceURL: String
    let language: GlucoseReportLanguage

    init(
        title: String? = nil,
        distribution: GlucoseReportRangeDistribution,
        usesMgDl: Bool,
        buckets: [GlucoseReportRangeBucket]? = nil,
        sourceText: String? = nil,
        sourceURL: String = GlucoseReportRangeDistribution.timeInRangeSourceURL,
        language: GlucoseReportLanguage
    ) {
        self.title = title ?? "\(language.text(.timeInRange)) (TIR)"
        self.distribution = distribution
        self.buckets = buckets ?? distribution.timeInRangeBuckets(usesMgDl: usesMgDl)
        self.usesMgDl = usesMgDl
        self.sourceText = sourceText ?? language.text(.timeInRangeSource)
        self.sourceURL = sourceURL
        self.language = language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)

            GeometryReader { geometry in
                // The printed clinical TIR bar must represent the exact percentage split while
                // still leaving tiny but visible slivers for very small low/high ranges.
                HStack(spacing: 1) {
                    ForEach(buckets) { bucket in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(bucket.color)
                            .frame(width: segmentWidth(for: bucket, totalWidth: geometry.size.width))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 17)
            .background(GlucoseReportColors.rule)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 6) {
                ForEach(buckets) { bucket in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(bucket.color)
                                .frame(width: 6, height: 6)
                            Text(bucket.title(language: language))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(GlucoseReportColors.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("(\(bucket.detail))")
                                .font(.system(size: 7.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(GlucoseReportFormatting.percentage(bucket.percentage))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(GlucoseReportColors.primaryText)
                                .monospacedDigit()
                            Text("(\(GlucoseReportFormatting.hoursPerDay(from: bucket.percentage, language: language)))")
                                .font(.system(size: 7.5))
                                .foregroundStyle(GlucoseReportColors.tertiaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text("\(sourceText): \(sourceURL)")
                .font(.system(size: 7))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GlucoseReportColors.clinicalBlue)
    }

    private func segmentWidth(for bucket: GlucoseReportRangeBucket, totalWidth: CGFloat) -> CGFloat {
        guard bucket.percentage > 0 else { return 0 }
        return max(2, totalWidth * CGFloat(bucket.percentage / 100))
    }
}
