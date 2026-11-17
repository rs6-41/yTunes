import Foundation

/// フォルダの永続アクセス権を保存・復元します。
nonisolated enum DownloadFolderStore {
    static let defaults = UserDefaults(suiteName: "group.com.rs6apps.yTunes")!
    static let pathKey = "downloadFolderPath"
    private static let key = "downloadFolderBookmark"

    static func restore() -> URL? {
        if let data = defaults.data(forKey: key) ?? UserDefaults.standard.data(forKey: key) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], bookmarkDataIsStale: &stale) {
                if stale { try? save(url) }
                return url
            }
        }
        if let path = defaults.string(forKey: pathKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return UserDefaults.standard.url(forKey: "selectedURL")
    }

    static func save(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: key)
        defaults.set(url.path, forKey: pathKey)
    }
}
