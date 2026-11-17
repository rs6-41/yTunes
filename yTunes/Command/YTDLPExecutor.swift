import Foundation

nonisolated enum YTDLPExecutor {
    static func run(tool: URL, ffmpeg: URL, folder: URL, request: DownloadRequest) async throws -> (status: Int32, output: String) {
        try await withCheckedThrowingContinuation { continuation in
            // パイプ読み取りと終了待ちでUIを止めないよう、専用キューで実行します。
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let pipe = Pipe()
                    let process = Process()
                    process.executableURL = tool
                    process.currentDirectoryURL = folder
                    process.arguments = ["--ffmpeg-location", ffmpeg.path] + request.arguments + ["--", request.pageURL.absoluteString]
                    process.standardOutput = pipe
                    process.standardError = pipe
                    process.standardInput = FileHandle.nullDevice
                    var environment = ProcessInfo.processInfo.environment
                    environment["PATH"] = [tool.deletingLastPathComponent().path, ffmpeg.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"].joined(separator: ":")
                    process.environment = environment
                    try process.run()
                    // 終了待ち前に読み取り、パイプが満杯になるのを防ぎます。
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
