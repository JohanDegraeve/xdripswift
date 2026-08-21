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

/// Temporary non-persistent browser used for Medtronic's CarePartner OAuth authorization.
@MainActor
final class CareLinkWebLoginViewController: UIViewController, WKNavigationDelegate {
    private let transaction: CareLinkAuthorizationTransaction
    private let prefill: CareLinkLoginPrefill
    private let completion = CareLinkOneShot()
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCareLinkFollowManager)
    private var continuation: CheckedContinuation<URL, Error>?
    private var hostNavigationController: UINavigationController?
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.customUserAgent = ConstantsCareLink.browserUserAgent
        return view
    }()

    init(transaction: CareLinkAuthorizationTransaction, prefill: CareLinkLoginPrefill) {
        self.transaction = transaction
        self.prefill = prefill
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
    func present(from presenter: UIViewController) async throws -> URL {
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
            presenter.present(navigation, animated: true) { [weak self] in
                guard let self else { return }
                webView.load(URLRequest(
                    url: transaction.authorizationURL,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                    timeoutInterval: ConstantsCareLink.loginTimeout
                ))
            }
        }
    }

    @objc private func cancelTapped() { cancel() }

    func cancel() { finish(.failure(CareLinkError.cancelled)) }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        prefillCredentials()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as? URLError)?.code != .cancelled else { return }
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard (error as? URLError)?.code != .cancelled else { return }
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              CareLinkOAuthCallback.matches(url, redirectURI: transaction.configuration.redirectURI) else {
            decisionHandler(.allow)
            return
        }
        // The custom CarePartner scheme belongs to Medtronic's app. Intercepting it before WebKit
        // opens the URL lets the bundled app complete OAuth without registering that foreign scheme.
        decisionHandler(.cancel)
        finish(.success(url))
    }

    private func prefillCredentials() {
        guard CareLinkLoginPrefillScript.allows(webView.url) else { return }
        webView.evaluateJavaScript(CareLinkLoginPrefillScript.script(prefill: prefill))
    }

    private func finish(_ result: Result<URL, Error>) {
        completion.run { [weak self] in
            guard let self else { return }
            let continuation = self.continuation
            self.continuation = nil
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
enum CareLinkLoginPrefillScript {
    static func allows(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        #if DEBUG
        if host == CareLinkClient.debugBaseURL?.host?.lowercased() { return true }
        #endif
        return host == "minimed.com" || host.hasSuffix(".minimed.com")
            || host == "minimed.eu" || host.hasSuffix(".minimed.eu")
    }

    static func script(prefill: CareLinkLoginPrefill) -> String {
        var object = [String: String]()
        if let username = prefill.username { object["username"] = username }
        if let password = prefill.password { object["password"] = password }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let values = String(data: data, encoding: .utf8) else {
            return ""
        }

        return """
        (() => {
            const credentials = \(values)
            const setValue = (field, value) => {
                if (!field || field.value || !value) return
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

enum CareLinkOAuthCallback {
    static func matches(_ url: URL, redirectURI: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare(redirectURI.scheme ?? "") == .orderedSame
            && (url.host ?? "").caseInsensitiveCompare(redirectURI.host ?? "") == .orderedSame
            && url.path == redirectURI.path
    }
}
