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
    let quality: VoiceQualityTier
    let gender: VoiceGender
    let isPersonal: Bool

    var displayName: String {
        let locale = Locale(identifier: "zh-Hans")
        let localizedLanguage = locale.localizedString(forIdentifier: language) ?? language
        let kind = isPersonal ? "个人声音" : quality.label
        return "\(name) · \(localizedLanguage) · \(kind)"
    }
}

enum VoiceQualityTier: Int, CaseIterable, Hashable, Comparable {
    case standard
    case enhanced
    case premium

    static func < (lhs: VoiceQualityTier, rhs: VoiceQualityTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .standard:
            return "标准"
        case .enhanced:
            return "增强"
        case .premium:
            return "高级"
        }
    }
}

enum VoiceGender: String, Hashable {
    case female
    case male
    case neutral
    case unspecified

    var label: String {
        switch self {
        case .female:
            return "女声"
        case .male:
            return "男声"
        case .neutral:
            return "中性"
        case .unspecified:
            return "未标注"
        }
    }
}

enum ParagraphHighlightColor: String, CaseIterable, Codable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow:
            return "书卷黄"
        case .green:
            return "护眼绿"
        case .blue:
            return "雾霾蓝"
        case .pink:
            return "浅粉"
        case .purple:
            return "淡紫"
        }
    }
}

struct AnnotationTextRange: Codable, Equatable, Hashable {
    let location: Int
    let length: Int

    init(_ range: NSRange) {
        location = range.location
        length = range.length
    }

    var nsRange: NSRange {
        NSRange(location: location, length: length)
    }
}

struct TextAnnotation: Identifiable, Codable, Equatable {
    let id: UUID
    let paragraphIndex: Int
    var range: AnnotationTextRange
    var selectedText: String
    var note: String
    var highlightColor: ParagraphHighlightColor?
    var isUnderlined: Bool
    var modifiedAt: Date

    var isEmpty: Bool {
        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && highlightColor == nil
            && !isUnderlined
    }
}

enum PersonalVoiceAccessState: Equatable {
    case notDetermined
    case denied
    case unsupported
    case authorized

    var label: String {
        switch self {
        case .notDetermined:
            return "尚未授权"
        case .denied:
            return "未获授权"
        case .unsupported:
            return "此设备不支持"
        case .authorized:
            return "已授权"
        }
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
