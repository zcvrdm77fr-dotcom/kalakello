import SwiftUI
import SwiftData

@main
struct KalakelloApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .modelContainer(for: [CatchRecord.self, SavedPlace.self])
    }
}
