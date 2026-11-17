import SwiftUI
import AppKit
import Combine
import SafariServices

struct SafariPopoverView: View {
    @ObservedObject var model: SafariPopoverModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isLoading {
                ProgressView().controlSize(.small)
            }
            if let url = model.pageURL {
                Text(url.absoluteString)
                    .font(.caption)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            Text(model.status)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: model.download) {
                Text("動画をダウンロード")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.pageURL == nil || model.isLoading)
        }
        .padding()
        .frame(width: 340, height: 240, alignment: .topLeading)
    }
}

