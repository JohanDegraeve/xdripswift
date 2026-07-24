//
//  ReportPDFGenerator.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

@MainActor
final class GlucoseReportPDFGenerator {
    func generatePDF(configuration: GlucoseReportConfiguration, analytics: GlucoseReportAnalytics, generatedAt: Date) async throws -> URL {
        let pageCount = 2
        let pageSize = configuration.paperSize.pageSize
        let reportsDirectory = try reportsDirectory()
        let fileURL = reportsDirectory
            .appendingPathComponent(fileName(configuration: configuration, generatedAt: generatedAt))
            .appendingPathExtension("pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: fileURL) { context in
            for pageNumber in 1 ... pageCount {
                context.beginPage()

                let pageView = GlucoseReportClinicalPageView(
                    configuration: configuration,
                    analytics: analytics,
                    generatedAt: generatedAt,
                    pageNumber: pageNumber,
                    pageCount: pageCount
                )
                .environment(\.colorScheme, .light)
                .environment(\.locale, configuration.language.locale)

                let renderer = ImageRenderer(content: pageView)
                renderer.scale = UIScreen.main.scale

                if let image = renderer.uiImage {
                    image.draw(in: CGRect(origin: .zero, size: pageSize))
                }
            }
        }

        return fileURL
    }

    private func reportsDirectory() throws -> URL {
        let documentsDirectory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let reportsDirectory = documentsDirectory.appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        return reportsDirectory
    }

    private func safeFileName(_ value: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let sanitized = value.unicodeScalars.map { allowedCharacters.contains($0) ? String($0) : "-" }.joined()
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fileName(configuration: GlucoseReportConfiguration, generatedAt: Date) -> String {
        let patientName = safeFileName(configuration.patientName).isEmpty ? "Patient" : safeFileName(configuration.patientName)
        let timestamp = Self.fileTimestampFormatter.string(from: generatedAt)
        return "\(patientName)_\(configuration.period.fileTitle)_\(timestamp)"
    }

    private static let fileTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter
    }()
}

extension Bundle {
    var glucoseReportAppVersion: String {
        guard let shortVersion = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !shortVersion.isEmpty else {
            return "-"
        }

        return shortVersion
    }
}
