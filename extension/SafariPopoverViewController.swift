import AppKit
import Combine
import SafariServices
import SwiftUI

final class SafariPopoverViewController: SFSafariExtensionViewController {
    static let shared = SafariPopoverViewController()
    private let model = SafariPopoverModel()

    private init() {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 340, height: 240)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        let hostingView = NSHostingView(rootView: SafariPopoverView(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 240)
        view = hostingView
        preferredContentSize = NSSize(width: 340, height: 240)
    }

    func loadPage(in window: SFSafariWindow) {
        model.loadPage(in: window)
    }

    func clearPage() {
        model.clearPage()
    }
}

final class SafariPopoverModel: ObservableObject {
    @Published private(set) var pageURL: URL?
    @Published private(set) var status = String(localized: "ページのURLを取得しています…")
    @Published private(set) var isLoading = true
    private var requestID = UUID()

    func clearPage() {
        requestID = UUID()
        pageURL = nil
        isLoading = false
    }

    func loadPage(in window: SFSafariWindow) {
        requestID = UUID()
        let request = requestID
        pageURL = nil
        isLoading = true
        status = String(localized: "ページのURLを取得しています…")
        window.getActiveTab { tab in
            guard let tab else {
                self.finish(nil, request: request)
                return
            }
            tab.getActivePage { page in
                guard let page else {
                    self.finish(nil, request: request)
                    return
                }
                page.getPropertiesWithCompletionHandler { properties in
                    self.finish(properties?.url, request: request)
                }
            }
        }
    }

    private func finish(_ url: URL?, request: UUID) {
        DispatchQueue.main.async {
            guard request == self.requestID else { return }
            self.isLoading = false
            guard let url else {
                self.status = String(localized: "URLを取得できませんでした。SafariでこのWebサイトへのアクセスを許可してください。")
                return
            }
            guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else {
                self.status = String(localized: "HTTP/HTTPSのページで実行してください。")
                return
            }
            self.pageURL = url
            self.status = String(localized: "現在のページをyt-dlpでダウンロードします。")
        }
    }

    func download() {
        guard let pageURL else { return }
        var components = URLComponents()
        components.scheme = "ytunes"
        components.host = "download"
        components.queryItems = [URLQueryItem(name: "url", value: pageURL.absoluteString)]
        guard let url = components.url else { return }
        if NSWorkspace.shared.open(url) {
            status = String(localized: "yTunesへ送信しました。")
        } else {
            status = String(localized: "yTunesを開けませんでした。本体を一度起動してから再実行してください。")
        }
    }
}
