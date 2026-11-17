import AppKit
import Combine
import Foundation

@MainActor
final class DownloadModel: ObservableObject {
    @Published var downloadURL = ""
    @Published var settings = DownloadSettings()
    @Published var selectedURL: URL?
    @Published var status = String(localized: "ツールを準備しています…")
    @Published var output = ""
    @Published var isRunning = false
    @Published var isReady = false
    private var tools: ToolSetup.Tools?
    private var pending: [DownloadRequest] = []
    private var didPrepare = false

    init() { selectedURL = DownloadFolderStore.restore() }

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
        do {
            try DownloadFolderStore.save(url)
            selectedURL = url
            runNext()
        } catch { status = error.localizedDescription }
    }

    func receive(_ url: URL) {
        do {
            let request = try DownloadLink.parse(url)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let received = request.settings { settings = received }
            enqueue(request)
        } catch { status = error.localizedDescription }
    }

    func enqueue(_ value: String) {
        do {
            guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw DownloadLink.LinkError.invalidPageURL
            }
            enqueue(try DownloadRequest(pageURL: url, settings: settings))
        } catch { status = error.localizedDescription }
    }

    private func enqueue(_ incoming: DownloadRequest) {
        var request = incoming
        do {
            if let destination = request.destinationURL {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    throw CocoaError(.fileNoSuchFile)
                }
                try DownloadFolderStore.save(destination)
                selectedURL = destination
            } else {
                selectedURL = DownloadFolderStore.restore()
                request.destinationURL = selectedURL
            }
        } catch {
            status = error.localizedDescription
            return
        }
        downloadURL = request.pageURL.absoluteString
        pending.append(request)
        if selectedURL == nil { status = String(localized: "保存先フォルダを選択してください。") }
        runNext()
    }

    private func runNext() {
        guard !isRunning, let tools, !pending.isEmpty,
              let folder = pending.first?.destinationURL ?? selectedURL else { return }
        let request = pending.removeFirst()
        let value = request.pageURL.absoluteString
        isRunning = true
        output = ""
        status = String(localized: "ダウンロード中: \(value)")
        Task {
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            do {
                let result = try await YTDLPExecutor.run(tool: tools.ytDLP, ffmpeg: tools.ffmpeg, folder: folder, request: request)
                output = result.output
                status = result.status == 0 ? String(localized: "ダウンロードが完了しました。") : String(localized: "ダウンロードに失敗しました（終了コード: \(result.status)）。")
            } catch {
                status = error.localizedDescription
            }
            isRunning = false
            runNext()
        }
    }

}
