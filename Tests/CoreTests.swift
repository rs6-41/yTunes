import Foundation

@main struct CoreTests {
    static func main() async throws {

        var settings = DownloadSettings()
precondition(settings.arguments.contains("--no-playlist"))
precondition(!settings.arguments.contains("--extract-audio"))
settings.resolution = .p1080
settings.videoFormat = .mp4
precondition(settings.arguments.contains("bv*[height<=1080]+ba/b[height<=1080]"))
precondition(settings.arguments.contains("--remux-video"))
settings.media = .audio
settings.audioFormat = .flac
settings.embedMetadata = true
settings.embedThumbnail = true
settings.downloadPlaylist = true
let arguments = settings.arguments
precondition(arguments.contains("--extract-audio"))
precondition(arguments.contains("flac"))
precondition(arguments.contains("--yes-playlist"))
precondition(arguments.contains("--embed-metadata"))
precondition(arguments.contains("--embed-thumbnail"))
precondition(!arguments.contains("--format"))
precondition(!arguments.contains("--remux-video"))
let encoded = try settings.encoded()
var link = URLComponents()
link.scheme = "ytunes"
link.host = "download"
link.queryItems = [URLQueryItem(name: "url", value: "https://example.org/watch?v=a&list=b"), URLQueryItem(name: "settings", value: encoded)]
let received = URLComponents(url: link.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "settings" }!.value!
let decoded = try DownloadSettings.decode(received)
precondition(decoded == settings)
precondition(decoded.arguments == arguments)
do {
    _ = try DownloadSettings.decode("{\"media\":\"unknown\"}")
    fatalError("Invalid settings accepted")
} catch is DecodingError {}
print("Video/audio arguments, toggles, settings URL round-trip, and invalid input checks passed.")

        let pageURL = URL(string: "https://example.org/watch?v=a&list=b#part")!
        let request = try DownloadLink.parse(DownloadLink.make(pageURL: pageURL, settings: settings))
        precondition(request.settings == settings && request.pageURL == pageURL)
        let result = try await YTDLPExecutor.run(tool: URL(fileURLWithPath: "/bin/echo"), ffmpeg: URL(fileURLWithPath: "/tmp/ffmpeg"), folder: FileManager.default.temporaryDirectory, request: request)
        precondition(result.status == 0 && result.output.contains("-- " + pageURL.absoluteString))
        let destination = URL(fileURLWithPath: "/tmp/日本語 & downloads", isDirectory: true)
        let folderLink = try DownloadLink.make(pageURL: pageURL, settings: settings, destinationURL: destination)
        let folderRequest = try DownloadLink.parse(folderLink)
        precondition(folderRequest.destinationURL?.path == destination.path)
        precondition(request.destinationURL == nil)
        for invalid in ["relative/path", ""] {
            var parts = URLComponents(url: folderLink, resolvingAgainstBaseURL: false)!
            parts.queryItems = parts.queryItems!.filter { $0.name != "destination" } + [URLQueryItem(name: "destination", value: invalid)]
            do {
                _ = try DownloadLink.parse(parts.url!)
                fatalError("Invalid folder accepted")
            } catch is DownloadLink.LinkError {}
        }
        print("URL scheme and process argument checks passed.")

    }
}
