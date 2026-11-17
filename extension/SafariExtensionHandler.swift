import SafariServices

final class SafariExtensionHandler: SFSafariExtensionHandler {
    private let controller = SafariPopoverViewController.shared

    override func popoverViewController() -> SFSafariExtensionViewController {
        controller
    }

    override func popoverWillShow(in window: SFSafariWindow) {
        controller.loadPage(in: window)
    }

    override func popoverDidClose(in window: SFSafariWindow) {
        controller.clearPage()
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        validationHandler(true, "")
    }
}
