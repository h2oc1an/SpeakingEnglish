import SwiftUI

@main
struct SpeakingEnglishApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home

    enum Tab {
        case home
        case transcription
        case translation
        case vocabulary
        case settings
    }
}
