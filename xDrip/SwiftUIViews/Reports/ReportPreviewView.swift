//
//  ReportPreviewView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import PDFKit
import SwiftUI
import UIKit

struct GlucoseReportPreviewView: View {
    let report: GlucoseReport
    @State private var shareItem: ReportShareItem?
    @State private var isPreparingProtectedShare = false
    @State private var shareErrorMessage: String?

    var body: some View {
        PDFKitReportView(url: report.pdfURL)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 5) {
                        if report.passwordToOpen != nil {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.green)
                        }

                        Text(navigationTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareShare()
                    } label: {
                        shareButtonIcon
                    }
                    .tint(.yellow)
                    .disabled(isPreparingProtectedShare)
                }
            }
            .overlay {
                if isPreparingProtectedShare {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        ProgressView()
                            .controlSize(.large)
                            .padding(18)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .alert(Texts_Common.reportUnableToPrepareTitle, isPresented: Binding(
                get: { shareErrorMessage != nil },
                set: { if !$0 { shareErrorMessage = nil } }
            )) {
                Button(Texts_Common.Ok, role: .cancel) {}
            } message: {
                Text(shareErrorMessage ?? "")
            }
            .sheet(item: $shareItem) { item in
                ReportShareSheet(url: item.url)
            }
    }

    private var shareButtonIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.title3)
            .accessibilityLabel(Texts_Common.reportShareAccessibility)
    }

    private func prepareShare() {
        guard let password = report.passwordToOpen else {
            shareItem = ReportShareItem(url: report.pdfURL)
            return
        }

        guard !isPreparingProtectedShare else { return }

        isPreparingProtectedShare = true
        shareErrorMessage = nil

        Task {
            do {
                let protectedURL = try await ReportPDFProtector.passwordProtectedCopy(of: report.pdfURL, password: password)
                shareItem = ReportShareItem(url: protectedURL)
            } catch {
                shareErrorMessage = error.localizedDescription
            }

            isPreparingProtectedShare = false
        }
    }

    private var navigationTitle: String {
        let periodTitle = String(format: Texts_Common.reportPeriodTitleFormat, report.configuration.period.rawValue)
        let patientName = report.configuration.patientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !patientName.isEmpty else {
            return periodTitle
        }

        return String(format: Texts_Common.reportPatientPeriodTitleFormat, patientName, periodTitle)
    }
}

private struct PDFKitReportView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemGroupedBackground
        pdfView.pageBreakMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

private struct ReportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ReportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum ReportPDFProtectionError: LocalizedError {
    case unableToOpenPDF
    case unableToWriteProtectedPDF

    var errorDescription: String? {
        switch self {
        case .unableToOpenPDF:
            return Texts_Common.reportPasswordProtectionOpenError
        case .unableToWriteProtectedPDF:
            return Texts_Common.reportPasswordProtectionWriteError
        }
    }
}

private enum ReportPDFProtector {
    static func passwordProtectedCopy(of sourceURL: URL, password: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: sourceURL) else {
                throw ReportPDFProtectionError.unableToOpenPDF
            }

            let protectedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent + "_Protected_\(UUID().uuidString)")
                .appendingPathExtension("pdf")

            let options: [PDFDocumentWriteOption: Any] = [
                .userPasswordOption: password,
                .ownerPasswordOption: password
            ]

            guard document.write(to: protectedURL, withOptions: options) else {
                throw ReportPDFProtectionError.unableToWriteProtectedPDF
            }

            return protectedURL
        }.value
    }
}
