import SwiftUI

struct AddWordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var word: String = ""
    @State private var meaning: String = ""
    @State private var context: String = ""
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("单词", text: $word)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("单词")
                }

                Section {
                    TextField("释义（可选）", text: $meaning)
                } header: {
                    Text("释义")
                }

                Section {
                    TextField("例句或上下文（可选）", text: $context)
                        .frame(minHeight: 80)
                } header: {
                    Text("上下文")
                }
            }
            .navigationTitle("添加单词")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveWord()
                    }
                    .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveWord() {
        let trimmedWord = word.trimmingCharacters(in: .whitespaces)

        guard trimmedWord.count >= 2 else {
            errorMessage = "单词至少需要2个字母"
            showingError = true
            return
        }

        guard trimmedWord.allSatisfy({ $0.isLetter }) else {
            errorMessage = "单词只能包含字母"
            showingError = true
            return
        }

        do {
            _ = try VocabularyService.shared.addWord(
                trimmedWord,
                meaning: meaning.isEmpty ? nil : meaning,
                context: context.isEmpty ? nil : context
            )
            onSave()
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            showingError = true
        }
    }
}
