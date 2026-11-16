import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var path_ytdlp: String = ""
    @State var path_ffmpeg: String = ""
    @State private var isImporterPresented = false
    @AppStorage("selectedURL") private var selectedURL: URL?
    
    @State var downloadURL = ""
    
    var body: some View {
        VStack {
            VStack(alignment:.leading) {
                HStack(spacing:3) {
                    if path_ytdlp != "" {
                        Image(systemName:"checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("ytdlp")
                }
                HStack(spacing:3) {
                    if path_ffmpeg != "" {
                        Image(systemName:"checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("ffmpeg")
                }
            }
            VStack {
                if path_ytdlp != "" && path_ffmpeg != "" {
                    TextField("URLを入力", text: $downloadURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .frame(width:300)
                    
                    HStack {
                        Button("フォルダを選択") {
                            isImporterPresented = true
                        }
                        if let url = selectedURL {
                            Text("\(url.path)")
                        }
                    }
                    Button(action: {
                        let tool = URL(fileURLWithPath:path_ytdlp)
                        let ffmpeg = URL(fileURLWithPath:path_ffmpeg)
                        if let savePath = selectedURL {
                            do {
                                try ytdlp(tool,ffmpeg:ffmpeg,path:savePath,url:downloadURL,options:[""])
                            } catch {
                            }
                        }
                    }) {
                        Text("ダウンロード開始")
                    }
                }
            }
        }
        .onAppear() {
            loadingCommand()
        }
        .fileImporter(
                    isPresented: $isImporterPresented,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
        ) { result in
            do {
                let urls = try result.get()
                if let url = urls.first {
                    // 永続的にアクセス権を保持したい場合はブックマーク作成や startAccessingSecurityScopedResource() を行う
                    _ = url.startAccessingSecurityScopedResource()
                    selectedURL = url
                    // 処理が終わったら url.stopAccessingSecurityScopedResource()
                }
            } catch {
                print("選択エラー: \(error.localizedDescription)")
            }
        }
    }
    func loadingCommand() {
        Task {
            do {
                let tools = try await ToolSetup.ensureInstalled()
                path_ytdlp = tools.ytDLP.path
                path_ffmpeg = tools.ffmpeg.path
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}
