import Foundation

/// フォーム変更後も実行内容が変わらないよう、登録時の設定を保持します。
nonisolated struct DownloadRequest: Sendable {
    var destinationURL: URL?
    let pageURL: URL
    let arguments: [String]
    let settings: DownloadSettings?

    init(pageURL: URL, settings: DownloadSettings) throws {
        try Self.validate(pageURL)
        self.pageURL = pageURL
        self.arguments = settings.arguments
        self.settings = settings
    }

    init(pageURL: URL, arguments: [String]) throws {
        try Self.validate(pageURL)
        self.pageURL = pageURL
        self.arguments = arguments
        self.settings = nil
    }

    static func validate(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            throw DownloadLink.LinkError.invalidPageURL
        }
    }
}
