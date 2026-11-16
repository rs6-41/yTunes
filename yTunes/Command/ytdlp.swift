import Foundation

@discardableResult
func ytdlp(_ tool: URL, ffmpeg: URL, path: URL, url: String, options: [String]
) throws -> Process {
    let process = Process()

    process.executableURL = tool
    process.currentDirectoryURL = path
    process.arguments = ["--ffmpeg-location", ffmpeg.path] + options + ["--", url]

    try process.run()

    return process
}
