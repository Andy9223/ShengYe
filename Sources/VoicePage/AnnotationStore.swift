import Foundation

final class AnnotationStore {
    private struct Archive: Codable {
        var books: [String: [TextAnnotation]] = [:]
    }

    private struct LegacyArchive: Codable {
        var books: [String: [String: LegacyParagraphAnnotation]] = [:]
    }

    private struct LegacyParagraphAnnotation: Codable {
        var note: String
        var highlightColor: ParagraphHighlightColor?
        var isUnderlined: Bool
        var originalText: String
        var modifiedAt: Date
    }

    static let shared = AnnotationStore()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    private init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = applicationSupport
            .appendingPathComponent("VoicePage", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("annotations.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func annotations(for document: ReadingDocument) -> [TextAnnotation] {
        guard let key = documentKey(for: document) else { return [] }
        let archive = loadArchive()
        let saved = archive.books[key] ?? []

        return saved.filter { annotation in
            guard let paragraph = document.paragraphs[
                safe: annotation.paragraphIndex
            ] else {
                return false
            }
            let nsText = paragraph.text as NSString
            let range = annotation.range.nsRange
            guard range.location >= 0,
                  range.length > 0,
                  NSMaxRange(range) <= nsText.length else {
                return false
            }
            return nsText.substring(with: range) == annotation.selectedText
        }
    }

    func save(
        _ annotations: [TextAnnotation],
        for document: ReadingDocument
    ) {
        guard let key = documentKey(for: document) else { return }
        var archive = loadArchive()

        if annotations.isEmpty {
            archive.books.removeValue(forKey: key)
        } else {
            archive.books[key] = annotations
        }

        guard let data = try? encoder.encode(archive) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func documentKey(for document: ReadingDocument) -> String? {
        document.sourceURL?.standardizedFileURL.path
    }

    private func loadArchive() -> Archive {
        guard let data = try? Data(contentsOf: fileURL) else {
            return Archive()
        }
        if let archive = try? decoder.decode(Archive.self, from: data) {
            return archive
        }
        guard let legacy = try? decoder.decode(
            LegacyArchive.self,
            from: data
        ) else {
            return Archive()
        }

        let migratedBooks = legacy.books.mapValues { saved in
            saved.compactMap { element -> TextAnnotation? in
                let key = element.key
                let value = element.value
                guard let paragraphIndex = Int(key),
                      !value.originalText.isEmpty else {
                    return nil
                }
                return TextAnnotation(
                    id: UUID(),
                    paragraphIndex: paragraphIndex,
                    range: AnnotationTextRange(
                        NSRange(
                            location: 0,
                            length: (value.originalText as NSString).length
                        )
                    ),
                    selectedText: value.originalText,
                    note: value.note,
                    highlightColor: value.highlightColor,
                    isUnderlined: value.isUnderlined,
                    modifiedAt: value.modifiedAt
                )
            }
        }
        return Archive(books: migratedBooks)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
