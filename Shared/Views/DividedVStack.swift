import SwiftUI

/// 条件分岐を解決した後の子ビュー間にだけ区切り線を挿入します。
struct DividedVStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(subviews) { subview in
                    if subview.id != subviews.first?.id {
                        Divider()
                    }
                    subview
                }
            }
        }
    }
}
