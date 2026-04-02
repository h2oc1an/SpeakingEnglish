import SwiftUI

struct WordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: VocabularyEntry
    @State private var isEditing: Bool = false
    @State private var editedMeaning: String = ""
    @State private var showingDeleteConfirmation: Bool = false

    let onUpdate: () -> Void

    init(entry: VocabularyEntry, onUpdate: @escaping () -> Void) {
        _entry = State(initialValue: entry)
        self.onUpdate = onUpdate
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(entry.word)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Spacer()

                        if entry.nextReviewDate <= Date() {
                            Text("待复习")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                }

                Section {
                    if isEditing {
                        TextField("释义", text: $editedMeaning)
                    } else {
                        Text(entry.meaning ?? "暂无释义")
                            .foregroundColor(entry.meaning == nil ? .secondary : .primary)
                    }
                } header: {
                    Text("释义")
                }

                if let context = entry.context, !context.isEmpty {
                    Section {
                        Text(context)
                    } header: {
                        Text("上下文")
                    }
                }

                Section {
                    LabeledContent("复习次数", value: "\(entry.repetitions)")
                    LabeledContent("简易因子", value: String(format: "%.2f", entry.easinessFactor))
                    LabeledContent("间隔天数", value: "\(entry.interval)")

                    if let lastReview = entry.lastReviewDate {
                        LabeledContent("上次复习") {
                            Text(lastReview, style: .relative)
                        }
                    }

                    LabeledContent("下次复习") {
                        Text(entry.nextReviewDate, style: .relative)
                    }
                } header: {
                    Text("学习进度")
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除单词")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("单词详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "编辑") {
                        if isEditing {
                            saveChanges()
                        } else {
                            editedMeaning = entry.meaning ?? ""
                        }
                        isEditing.toggle()
                    }
                }
            }
            .confirmationDialog("确认删除", isPresented: $showingDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    deleteWord()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("确定要删除这个单词吗？此操作不可撤销。")
            }
        }
    }

    private func saveChanges() {
        var updatedEntry = entry
        updatedEntry.meaning = editedMeaning.isEmpty ? nil : editedMeaning

        do {
            try VocabularyService.shared.updateWord(updatedEntry)
            entry = updatedEntry
            onUpdate()
        } catch {
            print("Failed to update word: \(error)")
        }
    }

    private func deleteWord() {
        do {
            try VocabularyService.shared.deleteWord(byId: entry.id)
            onUpdate()
            dismiss()
        } catch {
            print("Failed to delete word: \(error)")
        }
    }
}
