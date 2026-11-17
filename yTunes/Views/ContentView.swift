import SafariServices
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: DownloadModel
    @State var isDisplayAcknowledgementView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("拡張機能設定") {
                    SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.rs6apps.yTunes.extension") { error in
                        if let error {
                            Task { @MainActor in
                                model.status = String(localized: "Safariの拡張設定を開けませんでした: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                Spacer()
                Button(action: {
                    isDisplayAcknowledgementView = true
                }) {
                    Image(systemName:"questionmark.circle.fill")
                }
                .sheet(isPresented:$isDisplayAcknowledgementView) {
                    NavigationStack {
                        Text("謝辞")
                            .fontWeight(.black)
                        Text("yTunesは、以下のツールを自動でダウンロードし、外部プロセスとして実行します。\nこれらのツールの実行ファイルやソースコードには、それぞれのライセンスが適用されます。")
                        List {
                            Text("[Homebrew](https://brew.sh/)")
                            Text("[yt-dlp](https://github.com/yt-dlp/yt-dlp)")
                            Text("[FFmpeg](https://ffmpeg.org/)")
                        }
                        .listStyle(.inset)
                        .frame(height: 300)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(action: {
                                    isDisplayAcknowledgementView = false
                                }) {
                                    Text("閉じる")
                                }
                            }
                        }
                    }
                    .frame(width: 500)
                    .padding()
                }
            }
            TextField("URLを入力", text: $model.downloadURL)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
            DownloadOptionsForm(settings: $model.settings, onFolderSelected: model.selectFolder)
            Button("ダウンロード開始") {
                model.enqueue(model.downloadURL)
            }
            .disabled(!model.isReady || model.downloadURL.isEmpty)
            HStack {
                if model.isRunning || !model.isReady {
                    ProgressView().controlSize(.small)
                }
                Text(model.status).textSelection(.enabled)
            }
            if !model.isReady {
                Button("ツールの準備を再試行") {
                    Task { await model.prepare() }
                }
            }
            if !model.output.isEmpty {
                ScrollView {
                    Text(model.output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 220)
        .task { await model.prepare() }
    }
}
