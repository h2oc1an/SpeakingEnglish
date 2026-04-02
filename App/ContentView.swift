import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(AppState.Tab.home)

            TranscriptionView()
                .tabItem {
                    Label("转录", systemImage: "waveform")
                }
                .tag(AppState.Tab.transcription)

            TranslationView()
                .tabItem {
                    Label("翻译", systemImage: "character.bubble")
                }
                .tag(AppState.Tab.translation)

            VocabularyListView()
                .tabItem {
                    Label("生词本", systemImage: "book.fill")
                }
                .tag(AppState.Tab.vocabulary)

            SettingsAndReviewView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.settings)
        }
        .tint(.accentColor)
    }
}
