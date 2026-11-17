import SwiftUI

@main
struct yTunesApp: App {
    @StateObject private var model = DownloadModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onOpenURL { model.receive($0) }
        }
    }
}
