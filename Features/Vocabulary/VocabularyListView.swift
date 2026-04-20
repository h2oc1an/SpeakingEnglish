import SwiftUI
import Combine

struct VocabularyListView: View {
    @State private var words: [VocabularyEntry] = []
    @State private var searchText: String = ""
    @State private var showingAddWord: Bool = false
    @State private var selectedWord: VocabularyEntry?
    @State private var searchCancellable: AnyCancellable?

    var body: some View {
        NavigationStack {
            List {
                ForEach(words) { entry in
                    WordRowView(entry: entry)
                        .onTapGesture {
                            selectedWord = entry
                        }
                }
                .onDelete(perform: deleteWords)
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "搜索单词")
            .navigationTitle("生词本")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddWord = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWord) {
                AddWordView(onSave: { loadWords() })
            }
            .sheet(item: $selectedWord) { entry in
                WordDetailView(entry: entry, onUpdate: { loadWords() })
            }
            .onAppear {
                loadWords()
            }
            .refreshable {
                loadWords()
            }
            .onChange(of: searchText) { newValue in
                performSearchDebounced(query: newValue)
            }
        }
    }

    private func loadWords() {
        do {
            words = try VocabularyService.shared.getAllWords()
        } catch {
            print("Failed to load words: \(error)")
        }
    }

    private func performSearchDebounced(query: String) {
        searchCancellable?.cancel()

        if query.isEmpty {
            loadWords()
            return
        }

        searchCancellable = Just(query)
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [self] debouncedQuery in
                do {
                    words = try VocabularyService.shared.search(debouncedQuery)
                } catch {
                    print("Failed to search words: \(error)")
                }
            }
    }

    private func deleteWords(at offsets: IndexSet) {
        for index in offsets {
            let word = words[index]
            do {
                try VocabularyService.shared.deleteWord(byId: word.id)
                loadWords()
            } catch {
                print("Failed to delete word: \(error)")
            }
        }
    }
}

struct WordRowView: View {
    let entry: VocabularyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.word)
                    .font(.headline)

                Spacer()

                if entry.nextReviewDate <= Date() {
                    Text("待复习")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
            }

            if let meaning = entry.meaning, !meaning.isEmpty {
                Text(meaning)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Text("复习 \(entry.repetitions) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatDate(entry.nextReviewDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
