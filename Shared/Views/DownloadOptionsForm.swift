import SwiftUI
import UniformTypeIdentifiers

struct DownloadOptionsForm: View {
    @Binding var settings: DownloadSettings
    var onFolderSelected: (URL) -> Void = { _ in }
    @AppStorage(DownloadFolderStore.pathKey, store: DownloadFolderStore.defaults) private var folderPath = ""
    @State private var isImporterPresented = false
    @State private var folderError: String?
    
    var body: some View {
        DividedVStack {
            optionRow("保存場所", systemImage: "folder") {
                VStack(alignment: .trailing, spacing: 4) {
                    Button("フォルダを選択") { isImporterPresented = true }
                    if let folderError {
                        Text(folderError).font(.caption).foregroundStyle(.red)
                    }
                    Text(folderPath.isEmpty ? String(localized: "保存先未設定") : folderPath)
                        .font(.caption)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: 180, alignment: .trailing)
                }
            }
            optionRow("保存する内容",systemImage:"video.badge.waveform") {
                Picker("保存する内容", selection: $settings.media) {
                    Text("動画と音声").tag(DownloadSettings.Media.video)
                    Text("音声のみ").tag(DownloadSettings.Media.audio)
                }
                .labelsHidden()
            }
            if settings.media == .video {
                optionRow("動画形式",systemImage:"text.document") {
                    Picker("動画形式", selection: $settings.videoFormat) {
                        Text("自動").tag(DownloadSettings.VideoFormat.automatic)
                        ForEach([DownloadSettings.VideoFormat.mp4, .mkv, .webm], id: \.self) { format in
                            Text(format.rawValue.uppercased()).tag(format)
                        }
                    }
                        .labelsHidden()
                }
                optionRow("最大解像度",systemImage:"app.background.dotted") {
                    Picker("最大解像度", selection: $settings.resolution) {
                        Text("最高画質").tag(DownloadSettings.Resolution.best)
                        ForEach(DownloadSettings.Resolution.allCases.filter { $0.height != nil }, id: \.self) { resolution in
                            if let height = resolution.height { Text(verbatim: "\(height)p").tag(resolution) }
                        }
                    }
                        .labelsHidden()
                }
            } else {
                optionRow("音声形式",systemImage:"text.document") {
                    Picker("音声形式", selection: $settings.audioFormat) {
                        Text("元の形式を優先").tag(DownloadSettings.AudioFormat.best)
                        ForEach(DownloadSettings.AudioFormat.allCases.filter { $0 != .best }, id: \.self) { format in
                            Text(format.rawValue.uppercased()).tag(format)
                        }
                    }
                        .labelsHidden()
                }
            }
            optionRow("ファイル名",systemImage:"character.textbox.badge.sparkles") {
                Picker("ファイル名", selection: $settings.filename) {
                    Text("タイトル").tag(DownloadSettings.Filename.title)
                    Text("タイトルとID").tag(DownloadSettings.Filename.titleAndID)
                    Text("投稿日とタイトルとID").tag(DownloadSettings.Filename.dateAndTitle)
                }
                    .labelsHidden()
            }
            optionRow("プレイリスト全体を保存") {
                Toggle("プレイリスト全体を保存", isOn: $settings.downloadPlaylist)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
            }
            optionRow("メタデータを埋め込む") {
                Toggle("メタデータを埋め込む", isOn: $settings.embedMetadata)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
            }
            optionRow("サムネイルを埋め込む") {
                Toggle("サムネイルを埋め込む", isOn: $settings.embedThumbnail)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
            }
        }
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .toggleStyle(.switch)
        .onAppear {
            if folderPath.isEmpty, let url = DownloadFolderStore.restore() {
                try? DownloadFolderStore.save(url)
            }
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.folder]) { result in
            do {
                let url = try result.get()
                try DownloadFolderStore.save(url)
                folderError = nil
                onFolderSelected(url)
            } catch {
                folderError = error.localizedDescription
            }
        }
    }

    private func optionRow<Control: View>(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .labelIconToTitleSpacing(5)
            } else {
                Text(title)
            }
            Spacer(minLength: 8)
            control()
                .fixedSize()
        }
        .padding(.vertical, 10)
    }
}
