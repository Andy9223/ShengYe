import Foundation

struct LibraryBook: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var path: String
    var fileExtension: String
    var addedAt: Date
    var lastOpenedAt: Date
    var bookmarkData: Data?

    var fileURL: URL {
        URL(fileURLWithPath: path)
    }

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

struct ReadingHistoryEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var bookID: UUID
    var title: String
    var path: String
    var paragraphIndex: Int
    var chapterTitle: String
    var progressPercentage: Int
    var viewedAt: Date
}

enum ReadingHistoryPeriod: Int, CaseIterable, Identifiable, Hashable {
    case today
    case yesterday
    case dayBeforeYesterday
    case earlier

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today:
            return "今日"
        case .yesterday:
            return "昨日"
        case .dayBeforeYesterday:
            return "前天"
        case .earlier:
            return "更早"
        }
    }

    static func period(
        for date: Date,
        relativeTo now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> ReadingHistoryPeriod {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(
            byAdding: .day,
            value: -1,
            to: today
        ) ?? today
        let dayBeforeYesterday = calendar.date(
            byAdding: .day,
            value: -2,
            to: today
        ) ?? yesterday

        if date >= today {
            return .today
        }
        if date >= yesterday {
            return .yesterday
        }
        if date >= dayBeforeYesterday {
            return .dayBeforeYesterday
        }
        return .earlier
    }
}

struct ReadingLibrarySnapshot: Codable, Equatable {
    var books: [LibraryBook]
    var history: [ReadingHistoryEntry]

    static let empty = ReadingLibrarySnapshot(books: [], history: [])
}

struct ReadingLibraryStore {
    static let shared = ReadingLibraryStore()

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "VoicePage.readingLibrary.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load() -> ReadingLibrarySnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(
                ReadingLibrarySnapshot.self,
                from: data
              ) else {
            return .empty
        }
        return normalized(snapshot)
    }

    func save(_ snapshot: ReadingLibrarySnapshot) {
        guard let data = try? JSONEncoder().encode(normalized(snapshot)) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveURL(for book: LibraryBook) -> URL {
        if let bookmarkData = book.bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }
        }
        return book.fileURL
    }

    private func normalized(
        _ snapshot: ReadingLibrarySnapshot
    ) -> ReadingLibrarySnapshot {
        var seenPaths = Set<String>()
        let books = snapshot.books
            .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
            .filter {
                seenPaths.insert(
                    URL(fileURLWithPath: $0.path).standardizedFileURL.path
                ).inserted
            }

        let bookIDs = Set(books.map(\.id))
        var seenBookIDs = Set<UUID>()
        let history = snapshot.history
            .filter { bookIDs.contains($0.bookID) }
            .sorted { $0.viewedAt > $1.viewedAt }
            .filter { seenBookIDs.insert($0.bookID).inserted }

        return ReadingLibrarySnapshot(books: books, history: history)
    }
}
