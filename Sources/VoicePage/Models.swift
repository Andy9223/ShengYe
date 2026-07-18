import Foundation

enum AppScreen: Equatable {
    case library
    case reader
}

enum ThemePreference: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "白天"
        case .dark:
            return "黑夜"
        }
    }
}

struct ReadingDocument: Equatable {
    let title: String
    let sourceURL: URL?
    let paragraphs: [ReadingParagraph]
    let chapters: [ReadingChapter]
    let sections: [ReadingSection]

    static let welcome = ReadingDocument(
        title: "欢迎使用声页",
        sourceURL: nil,
        paragraphs: [
            ReadingParagraph(
                index: 0,
                text: "声页是一款为 macOS 设计的本地朗读阅读器。导入一本 EPUB 或 TXT 书籍，然后单击任意一句话即可从那里开始朗读。"
            ),
            ReadingParagraph(
                index: 1,
                text: "朗读过程中，当前句子会自动高亮。当朗读进入下一页时，阅读页面也会自动翻到对应位置，不需要手动操作。"
            ),
            ReadingParagraph(
                index: 2,
                text: "点击右侧的朗读图标，可以展开或收起控制栏。你可以暂停和继续朗读、更换系统音色、调节语速，还可以设置定时关闭。"
            ),
            ReadingParagraph(
                index: 3,
                text: "所有朗读均使用 macOS 自带的语音引擎，在本机完成。返回书库页面即可打开其他书籍。"
            )
        ],
        chapters: [
            ReadingChapter(index: 0, title: "使用说明", startParagraphIndex: 0)
        ],
        sections: [
            ReadingSection(
                index: 0,
                title: "使用说明",
                startParagraphIndex: 0,
                chapterIndex: 0
            )
        ]
    )
}

struct ReadingChapter: Identifiable, Equatable, Hashable {
    let index: Int
    let title: String
    let startParagraphIndex: Int

    var id: Int { index }
}

struct ReadingSection: Identifiable, Equatable, Hashable {
    let index: Int
    let title: String
    let startParagraphIndex: Int
    let chapterIndex: Int

    var id: Int { index }
}

struct ReadingParagraph: Identifiable, Equatable, Hashable {
    let index: Int
    let text: String

    var id: Int { index }
}

struct SentenceChunk: Identifiable, Equatable {
    let range: NSRange
    let text: String

    var id: Int { range.location }
}

enum SentenceSplitter {
    static func split(_ text: String) -> [SentenceChunk] {
        var chunks: [SentenceChunk] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.bySentences, .substringNotRequired]
        ) { _, range, _, _ in
            let nsRange = NSRange(range, in: text)
            chunks.append(
                SentenceChunk(range: nsRange, text: String(text[range]))
            )
        }

        if chunks.isEmpty, !text.isEmpty {
            return [
                SentenceChunk(
                    range: NSRange(location: 0, length: (text as NSString).length),
                    text: text
                )
            ]
        }
        return chunks
    }
}

struct ReadingPage: Identifiable, Equatable {
    let number: Int
    let fragments: [ReadingPageFragment]

    var id: Int { number }

    var paragraphIndices: [Int] {
        var seen = Set<Int>()
        return fragments.compactMap { fragment in
            seen.insert(fragment.paragraphIndex).inserted
                ? fragment.paragraphIndex
                : nil
        }
    }
}

struct ReadingPageFragment: Identifiable, Equatable {
    let paragraphIndex: Int
    let range: NSRange
    let sentenceStartOffset: Int

    var id: String {
        "\(paragraphIndex):\(range.location):\(range.length)"
    }
}

struct ReaderPageLayout: Equatable {
    let width: Double
    let height: Double

    static let initial = ReaderPageLayout(width: 660, height: 420)
}

enum PageTurnDirection: Equatable {
    case previous
    case next
}

struct TrackpadPageGesture {
    private(set) var accumulatedX: Double = 0
    private(set) var didTrigger = false
    private var lastTimestamp: TimeInterval = 0

    mutating func consume(
        horizontalDelta: Double,
        verticalDelta: Double,
        timestamp: TimeInterval,
        began: Bool,
        ended: Bool
    ) -> PageTurnDirection? {
        if began || timestamp - lastTimestamp > 0.35 {
            reset()
        }
        lastTimestamp = timestamp

        if ended {
            reset()
            return nil
        }

        guard abs(horizontalDelta) > abs(verticalDelta) * 1.15,
              abs(horizontalDelta) > 0.5 else {
            return nil
        }

        accumulatedX += horizontalDelta
        guard !didTrigger, abs(accumulatedX) >= 42 else {
            return nil
        }

        didTrigger = true
        // 直接采用 macOS 原始横向滚动语义，不做自然滚动方向校正。
        return accumulatedX < 0 ? .next : .previous
    }

    mutating func reset() {
        accumulatedX = 0
        didTrigger = false
    }
}

struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String

    var displayName: String {
        let locale = Locale(identifier: "zh-Hans")
        let localizedLanguage = locale.localizedString(forIdentifier: language) ?? language
        return "\(name) · \(localizedLanguage)"
    }
}

enum SleepTimerOption: String, CaseIterable, Identifiable {
    case off
    case tenMinutes
    case twentyMinutes
    case thirtyMinutes
    case sixtyMinutes
    case endOfSection
    case endOfChapter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:
            return "关闭定时"
        case .tenMinutes:
            return "10 分钟"
        case .twentyMinutes:
            return "20 分钟"
        case .thirtyMinutes:
            return "30 分钟"
        case .sixtyMinutes:
            return "60 分钟"
        case .endOfSection:
            return "读完本小节"
        case .endOfChapter:
            return "读完本章"
        }
    }

    var minutes: Int? {
        switch self {
        case .tenMinutes:
            return 10
        case .twentyMinutes:
            return 20
        case .thirtyMinutes:
            return 30
        case .sixtyMinutes:
            return 60
        case .off, .endOfSection, .endOfChapter:
            return nil
        }
    }
}
