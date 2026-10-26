import SwiftUI
import SwiftData

@main
struct SnakeKeeperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Persistence.shared.container)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            SnakeListView()
                .tabItem { Label("Collection", systemImage: "list.bullet.rectangle.portrait") }
            FeedingScheduleView()
                .tabItem { Label("Feeding", systemImage: "fork.knife") }
            PairingsListView()
                .tabItem { Label("Pairings", systemImage: "heart.circle") }
            GeneticsCalculatorView()
                .tabItem { Label("Genetics", systemImage: "square.grid.3x3") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onChange(of: scenePhase) { _, phase in
            // Last chance to write before Playgrounds or iPadOS stops the app.
            if phase != .active { context.saveNow() }
        }
        .safeAreaInset(edge: .top) {
            if Persistence.shared.isTemporary {
                Label("Data can't be saved on this device right now. See Settings → Storage.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.15))
                    .foregroundStyle(.red)
            }
        }
    }
}
