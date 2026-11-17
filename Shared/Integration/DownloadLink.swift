import Foundation

/// 本体と拡張でURLスキームの生成・検証を共通化します。
nonisolated enum DownloadLink {
    enum LinkError: LocalizedError {
        case invalidLink, invalidPageURL, invalidSettings

        var errorDescription: String? {
            switch self {
            case .invalidLink: String(localized: "受信したURLが不正です。")
            case .invalidPageURL: String(localized: "HTTP/HTTPSのURLを入力してください。")
            case .invalidSettings: String(localized: "ダウンロード設定が不正です。")
            }
        }
    }

    static func make(pageURL: URL, settings: DownloadSettings, destinationURL: URL? = nil) throws -> URL {
        try DownloadRequest.validate(pageURL)
        var components = URLComponents()
        components.scheme = "ytunes"
        components.host = "download"
        components.queryItems = [URLQueryItem(name: "url", value: pageURL.absoluteString), URLQueryItem(name: "settings", value: try settings.encoded())]
        if let destinationURL {
            guard destinationURL.isFileURL else { throw LinkError.invalidSettings }
            components.queryItems?.append(URLQueryItem(name: "destination", value: destinationURL.path))
        }
        guard let url = components.url else { throw LinkError.invalidLink }
        return url
    }

    static func parse(_ url: URL) throws -> DownloadRequest {
        guard url.scheme?.lowercased() == "ytunes", url.host?.lowercased() == "download",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.path.isEmpty, components.fragment == nil else { throw LinkError.invalidLink }
        let items = components.queryItems ?? []
        let pages = items.filter { $0.name == "url" }
        let settings = items.filter { $0.name == "settings" }
        let options = items.filter { $0.name == "options" }
        guard pages.count == 1, let value = pages.first?.value, let page = URL(string: value) else { throw LinkError.invalidLink }
        guard settings.count <= 1, options.count <= 1, settings.isEmpty || options.isEmpty else { throw LinkError.invalidSettings }
        let destinations = items.filter { $0.name == "destination" }
        guard destinations.count <= 1 else { throw LinkError.invalidSettings }
        var destinationURL: URL?
        if let item = destinations.first {
            guard let path = item.value, path.hasPrefix("/"), !path.contains("\0") else { throw LinkError.invalidSettings }
            destinationURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        var request: DownloadRequest
        if let item = settings.first {
            guard let value = item.value, let decoded = try? DownloadSettings.decode(value) else { throw LinkError.invalidSettings }
            request = try DownloadRequest(pageURL: page, settings: decoded)
        } else {
            request = try DownloadRequest(pageURL: page, arguments: YTDLPOptions.parse(options.first?.value ?? ""))
        }
        request.destinationURL = destinationURL
        return request
    }
}
