import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: tabBinding) {
            TodayView()
                .tabItem { Label("Nyt", systemImage: "gauge.with.dots.needle.67percent") }
                .tag(AppTab.today)
            SpotMapView()
                .tabItem { Label("Kartta", systemImage: "map.fill") }
                .tag(AppTab.map)
            CatchLogView()
                .tabItem { Label("Kirja", systemImage: "book.closed.fill") }
                .tag(AppTab.log)
            SaalisvirtaView()
                .tabItem { Label("Virta", systemImage: "fish.fill") }
                .tag(AppTab.saalisvirta)
            AboutView()
                .tabItem { Label("Tietoa", systemImage: "info.circle.fill") }
                .tag(AppTab.about)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task { await app.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                app.tick()
                Task { await app.load() }
            }
        }
    }

    private var tabBinding: Binding<AppTab> {
        Binding(get: { app.tab }, set: { app.tab = $0 })
    }
}
