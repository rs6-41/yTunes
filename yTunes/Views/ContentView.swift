import SafariServices
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: DownloadModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Safariの拡張機能設定を開く") {
                SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.rs6apps.yTunes.extension") { error in
                    if let error {
                        Task { @MainActor in
                            model.status = String(localized: "Safariの拡張設定を開けませんでした: \(error.localizedDescription)")
                        }
                    }
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
