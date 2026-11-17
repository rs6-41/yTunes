import SwiftUI
import AppKit
import Combine
import SafariServices

struct SafariPopoverView: View {
    @ObservedObject var model: SafariPopoverModel

    var body: some View {
        VStack(alignment: .leading,spacing:0) {
            Text("yTunes")
                .fontWeight(.black)
            Group {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
                Text(model.status)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .padding(.bottom,8)
            ScrollView {
                DownloadOptionsForm(settings: $model.settings)
            }
            HStack {
                Spacer()
                Button(action: model.download) {
                    Text("動画をダウンロード")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.pageURL == nil || model.isLoading)
                Spacer()
            }
            .padding(.top,8)
        }
        .padding()
        .frame(width: 350, height: 330, alignment: .topLeading)
    }
}

