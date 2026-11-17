import SwiftUI
import Foundation

enum ToolSetup {
    struct Tools: Sendable {
        let brew: URL
        let ytDLP: URL
        let ffmpeg: URL
        let ffprobe: URL
    }

    enum SetupError: LocalizedError {
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .failed(let message):
                message
            }
        }
    }

    private struct Release: Decodable {
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    private struct CommandResult: Sendable {
        let status: Int32
        let output: String
    }

    static func ensureInstalled() async throws -> Tools {
        try Task.checkCancellation()

        let brew: URL

        if let existing = findBrew() {
            brew = existing
        } else {
            try await installHomebrew()

            guard let installed = findBrew() else {
                throw SetupError.failed(String(localized: "Homebrewの導入を確認できませんでした。"))
            }

            brew = installed
        }

        _ = try await checkedRun(brew, ["--version"])

        let installed = try await checkedRun(
            brew,
            ["list", "--formula", "-1"]
        )

        let names = Set(
            installed.split(whereSeparator: \.isNewline).map(String.init)
        )

        let missing = ["yt-dlp", "ffmpeg"].filter {
            !names.contains($0)
        }

        if !missing.isEmpty {
            _ = try await checkedRun(
                brew,
                ["install"] + missing
            )
        }

        let ytPrefix = try await checkedRun(
            brew,
            ["--prefix", "yt-dlp"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let ffmpegPrefix = try await checkedRun(
            brew,
            ["--prefix", "ffmpeg"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let tools = Tools(
            brew: brew,
            ytDLP: URL(fileURLWithPath: ytPrefix)
                .appendingPathComponent("bin/yt-dlp"),
            ffmpeg: URL(fileURLWithPath: ffmpegPrefix)
                .appendingPathComponent("bin/ffmpeg"),
            ffprobe: URL(fileURLWithPath: ffmpegPrefix)
                .appendingPathComponent("bin/ffprobe")
        )

        _ = try await checkedRun(tools.ytDLP, ["--version"])
        _ = try await checkedRun(tools.ffmpeg, ["-version"])
        _ = try await checkedRun(tools.ffprobe, ["-version"])

        return tools
    }

    private static func findBrew() -> URL? {
        [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        .map { URL(fileURLWithPath: $0) }
        .first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    private static func installHomebrew() async throws {
        #if arch(arm64)
        let endpoint = URL(
            string: "https://api.github.com/repos/Homebrew/brew/releases/latest"
        )!

        var request = URLRequest(url: endpoint)
        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "MacToolSetup",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let release = try JSONDecoder().decode(Release.self, from: data)

        guard let asset = release.assets.first(where: {
            $0.name.hasPrefix("Homebrew-") && $0.name.hasSuffix(".pkg")
        }) else {
            throw SetupError.failed(String(localized: "公式インストーラーが見つかりませんでした。"))
        }

        let (download, downloadResponse) = try await URLSession.shared.download(
            from: asset.browser_download_url
        )
        try validate(downloadResponse)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let package = directory.appendingPathComponent("Homebrew.pkg")
        try FileManager.default.moveItem(at: download, to: package)

        _ = try await checkedRun(
            URL(fileURLWithPath: "/usr/sbin/pkgutil"),
            ["--check-signature", package.path]
        )

        try Task.checkCancellation()

        let command = "/usr/sbin/installer -pkg \(shellQuote(package.path)) -target /"
        let script = "do shell script \(appleScriptString(command)) with administrator privileges"

        _ = try await checkedRun(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            ["-e", script]
        )
        #else
        throw SetupError.failed(
            String(localized: "Intel Macでは手動でHomeBrewを導入する必要があります。")
        )
        #endif
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SetupError.failed(String(localized: "ダウンロードに失敗しました。"))
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func checkedRun(
        _ executable: URL,
        _ arguments: [String]
    ) async throws -> String {
        try Task.checkCancellation()

        let result = try await run(executable, arguments)

        guard result.status == 0 else {
            throw SetupError.failed(
                String(localized: "\(executable.lastPathComponent)の実行に失敗しました。\n\(result.output)")
            )
        }

        return result.output
    }

    private static func run(
        _ executable: URL,
        _ arguments: [String]
    ) async throws -> CommandResult {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<CommandResult, Error>) in

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    let pipe = Pipe()

                    process.executableURL = executable
                    process.arguments = arguments
                    process.standardOutput = pipe
                    process.standardError = pipe
                    process.standardInput = FileHandle.nullDevice

                    var environment = ProcessInfo.processInfo.environment
                    environment["PATH"] = [
                        executable.deletingLastPathComponent().path,
                        "/opt/homebrew/bin",
                        "/opt/homebrew/sbin",
                        "/usr/local/bin",
                        "/usr/local/sbin",
                        "/usr/bin",
                        "/bin",
                        "/usr/sbin",
                        "/sbin"
                    ].joined(separator: ":")

                    process.environment = environment

                    try process.run()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    continuation.resume(
                        returning: CommandResult(
                            status: process.terminationStatus,
                            output: String(decoding: data, as: UTF8.self)
                        )
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
