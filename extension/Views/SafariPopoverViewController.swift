import AppKit
import Combine
import SafariServices
import SwiftUI

final class SafariPopoverViewController: SFSafariExtensionViewController {
    static let shared = SafariPopoverViewController()
    private let model = SafariPopoverModel()

    private init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        let hostingView = NSHostingView(rootView: SafariPopoverView(model: model))
        view = hostingView
    }

    func loadPage(in window: SFSafariWindow) {
        model.loadPage(in: window)
    }

    func clearPage() {
        model.clearPage()
    }
}
