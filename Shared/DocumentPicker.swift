import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    let supportedTypes: [UTType]
    let pickerMode: UIDocumentPickerMode
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else { return }

            let originalFileName = url.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(originalFileName)

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                onPick([tempURL])
            } catch {
                print("Failed to copy file: \(error)")
            }

            url.stopAccessingSecurityScopedResource()
        }
    }
}

// MARK: - Subtitle Picker
struct SubtitlePickerView: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let subtitleTypes: [UTType] = [
            UTType(filenameExtension: "srt") ?? .plainText,
            UTType(filenameExtension: "ass") ?? .plainText,
            UTType(filenameExtension: "ssa") ?? .plainText
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: subtitleTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void

        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            let ext = url.pathExtension.lowercased()
            guard ["srt", "ass", "ssa"].contains(ext) else { return }

            guard url.startAccessingSecurityScopedResource() else { return }

            let originalFileName = url.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(originalFileName)

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                onSelect(tempURL)
            } catch {
                print("Failed to copy subtitle file: \(error)")
            }

            url.stopAccessingSecurityScopedResource()
        }
    }
}
