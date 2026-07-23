import Foundation

enum BookCoverStore {
    static func coverData(
        bookID: UUID,
        sourceURL: URL,
        fileExtension: String
    ) -> Data? {
        let cachedURL = cacheURL(for: bookID)
        if let cachedData = try? Data(contentsOf: cachedURL) {
            return cachedData
        }

        guard fileExtension.lowercased() == "epub",
              let coverData = DocumentLoader.loadCoverData(from: sourceURL) else {
            return nil
        }

        try? FileManager.default.createDirectory(
            at: coversDirectory,
            withIntermediateDirectories: true
        )
        try? coverData.write(to: cachedURL, options: .atomic)
        return coverData
    }

    static func removeCover(bookID: UUID) {
        try? FileManager.default.removeItem(at: cacheURL(for: bookID))
    }

    private static var coversDirectory: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("VoicePage", isDirectory: true)
            .appendingPathComponent("BookCovers", isDirectory: true)
    }

    private static func cacheURL(for bookID: UUID) -> URL {
        coversDirectory.appendingPathComponent(
            "\(bookID.uuidString).cover"
        )
    }
}
