import SwiftUI
import SwiftData

@main
struct SnakeKeeperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Snake.self,
            FeedingRecord.self,
            SnakePhoto.self,
            Concern.self,
            Pairing.self,
            CustomGene.self,
        ])
    }
}

struct ContentView: View {
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
    }
}
