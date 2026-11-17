import Foundation

nonisolated struct DownloadSettings: Codable, Equatable, Sendable {
    enum Media: String, Codable, CaseIterable, Sendable {
        case video, audio
    }

    enum VideoFormat: String, Codable, CaseIterable, Sendable {
        case automatic, mp4, mkv, webm
    }

    enum AudioFormat: String, Codable, CaseIterable, Sendable {
        case best, mp3, m4a, flac, wav, opus
    }

    enum Resolution: String, Codable, CaseIterable, Sendable {
        case best, p2160, p1440, p1080, p720, p480

        var height: Int? {
            Int(rawValue.dropFirst())
        }
    }

    enum Filename: String, Codable, CaseIterable, Sendable {
        case titleAndID, title, dateAndTitle

        var template: String {
            switch self {
            case .titleAndID: "%(title)s [%(id)s].%(ext)s"
            case .title: "%(title)s.%(ext)s"
            case .dateAndTitle: "%(upload_date)s - %(title)s [%(id)s].%(ext)s"
            }
        }
    }

    var media: Media = .video
    var videoFormat: VideoFormat = .automatic
    var audioFormat: AudioFormat = .mp3
    var resolution: Resolution = .best
    var filename: Filename = .title
    var downloadPlaylist = false
    var embedMetadata = false
    var embedThumbnail = false

    var arguments: [String] {
        var result = [downloadPlaylist ? "--yes-playlist" : "--no-playlist"]
        switch media {
        case .video:
            if let height = resolution.height {
                result += ["--format", "bv*[height<=\(height)]+ba/b[height<=\(height)]"]
            }
            if videoFormat != .automatic {
                result += ["--merge-output-format", videoFormat.rawValue, "--remux-video", videoFormat.rawValue]
            }
        case .audio:
            result += ["--extract-audio", "--audio-format", audioFormat.rawValue, "--audio-quality", "0"]
        }
        result += ["--output", filename.template]
        if embedMetadata { result.append("--embed-metadata") }
        if embedThumbnail { result.append("--embed-thumbnail") }
        return result
    }

    func encoded() throws -> String {
        String(decoding: try JSONEncoder().encode(self), as: UTF8.self)
    }

    static func decode(_ value: String) throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(value.utf8))
    }
}
