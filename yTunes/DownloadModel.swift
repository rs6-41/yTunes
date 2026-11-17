import AppKit
import Combine
import Foundation

@MainActor
final class DownloadModel: ObservableObject {
    @Published var downloadURL = ""
    @Published var selectedURL: URL?
    @Published var status = String(localized: "ツールを準備しています…")
    @Published var output = ""
    @Published var isRunning = false
    @Published var isReady = false
    private var tools: ToolSetup.Tools?
    private var pending: [String] = []
    private var didPrepare = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "downloadFolderBookmark") {
            var stale = false
            selectedURL = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], bookmarkDataIsStale: &stale)
        }
        if selectedURL == nil {
            selectedURL = UserDefaults.standard.url(forKey: "selectedURL")
        }
    }

    func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true
        do {
            tools = try await ToolSetup.ensureInstalled()
            isReady = true
            status = pending.isEmpty ? String(localized: "準備完了") : String(localized: "保存先フォルダを選択してください。")
            runNext()
        } catch {
            didPrepare = false
            status = error.localizedDescription
        }
    }

    func selectFolder(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: "downloadFolderBookmark")
            selectedURL = url
            runNext()
        } catch {
            status = error.localizedDescription
        }
    }

    func receive(_ url: URL) {
        guard url.scheme == "ytunes", url.host == "download",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "url" })?.value else {
            status = String(localized: "受信したURLが不正です。")
            return
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        enqueue(value)
    }

    func enqueue(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), url.host != nil else {
            status = String(localized: "HTTP/HTTPSのURLを入力してください。")
            return
        }
        downloadURL = value
        pending.append(value)
        if selectedURL == nil { status = String(localized: "保存先フォルダを選択してください。") }
        runNext()
    }

    private func runNext() {
        guard !isRunning, let tools, let folder = selectedURL, !pending.isEmpty else { return }
        let value = pending.removeFirst()
        isRunning = true
        output = ""
        status = String(localized: "ダウンロード中: \(value)")
        Task {
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            do {
                let result = try await Self.execute(tool: tools.ytDLP, ffmpeg: tools.ffmpeg, folder: folder, url: value)
                output = result.output
                status = result.status == 0 ? String(localized: "ダウンロードが完了しました。") : String(localized: "ダウンロードに失敗しました（終了コード: \(result.status)）。")
            } catch {
                status = error.localizedDescription
            }
            isRunning = false
            runNext()
        }
    }

    nonisolated private static func execute(tool: URL, ffmpeg: URL, folder: URL, url: String) async throws -> (status: Int32, output: String) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let pipe = Pipe()
                    let process = Process()
                    process.executableURL = tool
                    process.currentDirectoryURL = folder
                    process.arguments = ["--ffmpeg-location", ffmpeg.path, "--", url]
                    process.standardOutput = pipe
                    process.standardError = pipe
                    process.standardInput = FileHandle.nullDevice
                    var environment = ProcessInfo.processInfo.environment
                    environment["PATH"] = [tool.deletingLastPathComponent().path, ffmpeg.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"].joined(separator: ":")
                    process.environment = environment
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: (process.terminationStatus, String(decoding: data, as: UTF8.self)))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
