import SwiftUI

// MARK: - Bookmark List Sheet
struct BookmarkListSheet: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.bookmarks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("暂无书签")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(viewModel.bookmarks) { bookmark in
                            BookmarkRow(bookmark: bookmark) {
                                viewModel.jumpToBookmark(bookmark)
                                dismiss()
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                viewModel.deleteBookmark(viewModel.bookmarks[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("书签列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bookmark Row
struct BookmarkRow: View {
    let bookmark: VideoBookmark
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TimeFormatter.formatMinutesSeconds(bookmark.timestamp))
                        .font(.headline)
                    if let note = bookmark.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Add Bookmark Sheet
struct AddBookmarkSheet: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("时间")
                        Spacer()
                        Text(TimeFormatter.formatMinutesSeconds(viewModel.currentTime))
                            .foregroundColor(.secondary)
                    }
                }

                Section("备注 (可选)") {
                    TextField("添加备注...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        viewModel.addBookmark(note: note.isEmpty ? nil : note)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}