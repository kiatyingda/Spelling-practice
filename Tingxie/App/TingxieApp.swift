import SwiftData
import SwiftUI

@main
struct TingxieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Sheet.self, Item.self, SessionLog.self])
    }
}

/// Child area by default; the parent area sits behind a 1.5s long-press.
struct RootView: View {
    @State private var parentMode = false

    var body: some View {
        Group {
            if parentMode {
                ParentHomeView { parentMode = false }
            } else {
                ChildHomeView { parentMode = true }
            }
        }
        .tint(Theme.accent)
    }
}
