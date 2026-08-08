//
//  CareLinkWebLogin.swift
//  xdripswift
//
//  Created by Paul Plant on 2/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import os

/// Temporary non-persistent browser used to establish the personal CareLink session.
/// WKWebView is required because ASWebAuthenticationSession does not return session cookies.
@MainActor
final class CareLinkWebLoginViewController: UIViewController, WKNavigationDelegate, WKHTTPCookieStoreObserver {
    private let loginURL: URL
    private let credentials: CareLinkLoginCredentials
    private let completion = CareLinkOneShot()
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCareLinkFollowManager)
    private var continuation: CheckedContinuation<[HTTPCookie], Error>?
    private var hostNavigationController: UINavigationController?
    private var cookieInspectionInFlight = false
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
        return view
    }()

    init(loginURL: URL, credentials: CareLinkLoginCredentials) {
        self.loginURL = loginURL
        self.credentials = credentials
        super.init(nibName: nil, bundle: nil)
        title = Texts_SettingsView.careLinkLogIn
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() { view = webView }

    /// Returns the visible controller in the active scene for the login sheet.
    static func topViewController() -> UIViewController? {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return nil }
        var visible = root
        while let presented = visible.presentedViewController { visible = presented }
        return visible
    }

    /// Presents once and resumes exactly once if dismissal races a navigation callback.
    func present(from presenter: UIViewController) async throws -> [HTTPCookie] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancelTapped)
            )
            let navigation = UINavigationController(rootViewController: self)
            navigation.modalPresentationStyle = .pageSheet
            navigation.isModalInPresentation = true
            navigation.sheetPresentationController?.detents = [.large()]
            navigation.sheetPresentationController?.prefersGrabberVisible = true
            hostNavigationController = navigation
            webView.configuration.websiteDataStore.httpCookieStore.add(self)
            presenter.present(navigation, animated: true) { [weak self] in
                guard let self else { return }
                webView.load(URLRequest(
                    url: loginURL,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                    timeoutInterval: 60
                ))
            }
        }
    }

    @objc private func cancelTapped() { cancel() }

    func cancel() { finish(.failure(CareLinkError.cancelled)) }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        inspectCookies(reason: "navigation started")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        prefillCredentials()
        inspectCookies(reason: "navigation finished")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        inspectCookies(reason: "navigation failed")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as? URLError)?.code != .cancelled {
            inspectCookies(reason: "provisional navigation failed")
        }
    }

    /// Medtronic can set the final cookies after navigation through an asynchronous page request.
    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor [weak self] in self?.inspectCookies(reason: "cookie store changed") }
    }

    /// Fills empty fields on Medtronic pages. The user still submits forms and completes MFA.
    private func prefillCredentials() {
        guard CareLinkLoginPrefill.allows(webView.url) else { return }
        webView.evaluateJavaScript(CareLinkLoginPrefill.script(credentials: credentials))
    }

    /// Completes only after both required session cookies exist and have not expired.
    private func inspectCookies(reason: String) {
        guard !cookieInspectionInFlight else { return }
        cookieInspectionInFlight = true
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            Task { @MainActor [weak self] in
                guard let self else { return }
                cookieInspectionInFlight = false
                let expiryValues = cookies.filter { $0.name == "c_token_valid_to" }
                let newestExpiry = expiryValues.compactMap { CareLinkClient.parseExpiry($0.value) }.max()
                let names = cookies.map { "\($0.name)@\($0.domain)" }.sorted().joined(separator: ",")
                let rawExpiry = expiryValues.map(\.value).joined(separator: ",")
                trace(
                    "CareLink browser cookie check reason=%{public}@ url=%{public}@ cookies=%{public}@ validTo=%{public}@ parsedValidTo=%{public}@",
                    log: log,
                    category: ConstantsLog.categoryCareLinkFollowManager,
                    type: .info,
                    reason,
                    webView.url?.absoluteString ?? "<none>",
                    names,
                    rawExpiry,
                    newestExpiry?.description ?? "<missing>"
                )
                guard let newestExpiry,
                      newestExpiry > Date(),
                      cookies.contains(where: { $0.name == "auth_tmp_token" }) else { return }
                finish(.success(cookies))
            }
        }
    }

    private func finish(_ result: Result<[HTTPCookie], Error>) {
        completion.run { [weak self] in
            guard let self else { return }
            let continuation = self.continuation
            self.continuation = nil
            webView.configuration.websiteDataStore.httpCookieStore.remove(self)
            webView.stopLoading()
            trace(
                "CareLink browser completing authentication",
                log: log,
                category: ConstantsLog.categoryCareLinkFollowManager,
                type: .info
            )
            continuation?.resume(with: result)
            hostNavigationController?.dismiss(animated: true)
        }
    }
}

/// Creates the page-local script used by the temporary login browser.
enum CareLinkLoginPrefill {
    static func allows(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        #if DEBUG
        if host == CareLinkClient.debugBaseURL?.host?.lowercased() { return true }
        #endif
        return host == "minimed.com" || host.hasSuffix(".minimed.com")
            || host == "minimed.eu" || host.hasSuffix(".minimed.eu")
    }

    static func script(credentials: CareLinkLoginCredentials) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [
            "username": credentials.username,
            "password": credentials.password
        ]), let values = String(data: data, encoding: .utf8) else {
            return ""
        }

        return """
        (() => {
            const credentials = \(values)
            const setValue = (field, value) => {
                if (!field || field.value) return
                const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value")?.set
                if (setter) setter.call(field, value)
                else field.value = value
                field.dispatchEvent(new Event("input", { bubbles: true }))
                field.dispatchEvent(new Event("change", { bubbles: true }))
            }
            const firstField = selectors => selectors.map(selector => document.querySelector(selector)).find(Boolean)
            const fill = () => {
                setValue(firstField([
                    'input[autocomplete="username"]',
                    'input[name="username"]',
                    'input[name="email"]',
                    'input[type="email"]'
                ]), credentials.username)
                setValue(firstField([
                    'input[autocomplete="current-password"]',
                    'input[name="password"]',
                    'input[type="password"]'
                ]), credentials.password)
            }
            fill()
            const observer = new MutationObserver(fill)
            observer.observe(document.documentElement, { childList: true, subtree: true })
            window.setTimeout(() => observer.disconnect(), 15000)
        })()
        """
    }
}
