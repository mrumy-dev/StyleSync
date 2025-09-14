import SwiftUI
import SwiftData

@main
struct StyleSyncApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [StyleItem.self, Collection.self])
    }
}