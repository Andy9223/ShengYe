import AppKit
import AVFoundation
import Foundation

private struct SpeechParagraphMapping {
    let paragraphIndex: Int
    let utteranceRange: NSRange
    let paragraphBaseOffset: Int
}

@MainActor
final class ReaderViewModel: NSObject, ObservableObject {
    @Published var screen: AppScreen = .library
    @Published private(set) var document: ReadingDocument = .welcome
    @Published private(set) var pages: [ReadingPage] = []
    @Published var currentPage = 0
    @Published private(set) var pageTurnDirection: PageTurnDirection = .next
    @Published private(set) var selectedChapterIndex = 0
    @Published private(set) var currentParagraphIndex: Int?
    @Published private(set) var highlightedRange: NSRange?
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published private(set) var isLoading = false
    @Published var controlsExpanded = false
    @Published var selectedVoiceID: String
    @Published var speechRate: Float
    @Published var themePreference: ThemePreference
    @Published var fontSize: Double
    @Published var pageBrightness: Double
    @Published private(set) var timerOption: SleepTimerOption = .off
    @Published private(set) var timerEndDate: Date?
    @Published private(set) var clockText = ""
    @Published private(set) var batteryText = "—"
    @Published var errorMessage: String?
    @Published private(set) var voices: [VoiceOption]
    @Published private(set) var favoriteVoiceIDs: Set<String>
    @Published private(set) var annotations: [TextAnnotation] = []
    @Published var eyeCareMode: Bool
    @Published private(set) var personalVoiceAccessState: PersonalVoiceAccessState
    @Published private(set) var isFollowingSpeech = true
    @Published private(set) var libraryBooks: [LibraryBook]
    @Published private(set) var readingHistory: [ReadingHistoryEntry]
    @Published private(set) var bookCoverImages: [UUID: NSImage] = [:]
    @Published var autoFollowSpeech: Bool

    private let synthesizer = AVSpeechSynthesizer()
    private let previewSynthesizer = AVSpeechSynthesizer()
    private let annotationStore = AnnotationStore.shared
    private let readingLibraryStore = ReadingLibraryStore.shared
    private var timerTask: Task<Void, Never>?
    private var stopBoundaryParagraphIndex: Int?
    private var shouldContinueAfterFinish = false
    private var activeUtteranceID: ObjectIdentifier?
    private var activeSpeechMappings: [SpeechParagraphMapping] = []
    private var pendingSpeechOffset = 0
    private var systemStatusTimer: Timer?
    private var pageLayout = ReaderPageLayout.initial
    private var inputMonitor: Any?
    private var trackpadPageGesture = TrackpadPageGesture()

    private let defaults = UserDefaults.standard
    private let voiceKey = "VoicePage.selectedVoice"
    private let rateKey = "VoicePage.speechRate"
    private let themeKey = "VoicePage.theme"
    private let fontSizeKey = "VoicePage.fontSize"
    private let brightnessKey = "VoicePage.pageBrightness"
    private let progressKey = "VoicePage.readingProgress"
    private let favoriteVoicesKey = "VoicePage.favoriteVoices"
    private let eyeCareKey = "VoicePage.eyeCareMode"
    private let autoFollowSpeechKey = "VoicePage.autoFollowSpeech"

    override init() {
        let availableVoices = Self.availableVoiceOptions()
        let savedLibrary = ReadingLibraryStore.shared.load()

        voices = availableVoices
        libraryBooks = savedLibrary.books
        readingHistory = savedLibrary.history
        favoriteVoiceIDs = Set(
            defaults.stringArray(forKey: favoriteVoicesKey) ?? []
        )

        let savedVoiceID = defaults.string(forKey: voiceKey)
        let preferredChineseVoice = availableVoices.first {
            $0.language == "zh-CN" || $0.language == "zh-Hans"
        }
        selectedVoiceID = availableVoices.contains(where: { $0.id == savedVoiceID })
            ? savedVoiceID!
            : (preferredChineseVoice?.id ?? availableVoices.first?.id ?? "")

        let savedRate = defaults.object(forKey: rateKey) as? NSNumber
        speechRate = savedRate?.floatValue ?? 0.46
        themePreference = ThemePreference(
            rawValue: defaults.string(forKey: themeKey) ?? ""
        ) ?? .system
        fontSize = (defaults.object(forKey: fontSizeKey) as? NSNumber)?.doubleValue ?? 20
        pageBrightness = (defaults.object(forKey: brightnessKey) as? NSNumber)?.doubleValue ?? 1
        eyeCareMode = defaults.bool(forKey: eyeCareKey)
        autoFollowSpeech = defaults.object(forKey: autoFollowSpeechKey) == nil
            ? true
            : defaults.bool(forKey: autoFollowSpeechKey)
        personalVoiceAccessState = Self.personalVoiceAccessState(
            from: AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        )

        super.init()
        isFollowingSpeech = autoFollowSpeech
        migrateLegacyProgressIfNeeded()
        refreshBookCovers()
        synthesizer.delegate = self
        installInputMonitor()
        rebuildPages()
        refreshSystemStatus()
        systemStatusTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSystemStatus()
            }
        }
    }

    deinit {
        timerTask?.cancel()
        systemStatusTimer?.invalidate()
        if let inputMonitor {
            NSEvent.removeMonitor(inputMonitor)
        }
    }

    var currentVoiceName: String {
        voices.first(where: { $0.id == selectedVoiceID })?.name ?? "系统默认"
    }

    var currentVoiceQuality: VoiceQualityTier {
        voices.first(where: { $0.id == selectedVoiceID })?.quality ?? .standard
    }

    var currentVoiceIsPersonal: Bool {
        voices.first(where: { $0.id == selectedVoiceID })?.isPersonal ?? false
    }

    var annotationCount: Int {
        annotations.count
    }

    var personalVoiceCount: Int {
        voices.filter(\.isPersonal).count
    }

    var currentPageLabel: String {
        guard !pages.isEmpty else { return "0 / 0" }
        return "\(currentPage + 1) / \(pages.count)"
    }

    var currentChapterTitle: String {
        document.chapters.first(where: { $0.index == selectedChapterIndex })?.title
            ?? "全文"
    }

    var statusText: String {
        if isLoading { return "正在打开书籍…" }
        if isPaused { return "已暂停" }
        if isSpeaking { return "正在朗读" }
        return "准备就绪"
    }

    var readingProgressPercentage: Int {
        guard !pages.isEmpty else { return 0 }
        return Int(
            (Double(currentPage + 1) / Double(pages.count) * 100).rounded()
        )
    }

    var hasOpenBook: Bool {
        document.sourceURL != nil
    }

    var lastReadingHistory: ReadingHistoryEntry? {
        readingHistory.first
    }

    func openDocument(_ url: URL) {
        stop()
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedDocument = try await Task.detached(priority: .userInitiated) {
                    try DocumentLoader.load(from: url)
                }.value
                registerInLibrary(loadedDocument)
                applyDocument(loadedDocument)
                saveProgress(currentParagraphIndex ?? 0)
                screen = .reader
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func returnToLibrary() {
        stop()
        screen = .library
    }

    func continueReading() {
        guard hasOpenBook else { return }
        screen = .reader
    }

    func openLibraryBook(_ book: LibraryBook) {
        let url = readingLibraryStore.resolveURL(for: book)
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "找不到《\(book.title)》的原文件。文件可能已被移动或删除，请重新导入。"
            return
        }
        openDocument(url)
    }

    func openHistoryEntry(_ entry: ReadingHistoryEntry) {
        guard let book = libraryBooks.first(where: { $0.id == entry.bookID }) else {
            errorMessage = "这本书已不在“我的图书”中，请重新导入。"
            return
        }
        openLibraryBook(book)
    }

    func openLastReadingProgress() {
        guard let entry = lastReadingHistory else { return }
        openHistoryEntry(entry)
    }

    func historyEntry(for bookID: UUID) -> ReadingHistoryEntry? {
        readingHistory.first { $0.bookID == bookID }
    }

    func bookCoverImage(for bookID: UUID) -> NSImage? {
        bookCoverImages[bookID]
    }

    func removeLibraryBook(id: UUID) {
        libraryBooks.removeAll { $0.id == id }
        readingHistory.removeAll { $0.bookID == id }
        bookCoverImages.removeValue(forKey: id)
        BookCoverStore.removeCover(bookID: id)
        persistReadingLibrary()
    }

    func removeHistory(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        readingHistory.removeAll { ids.contains($0.id) }
        persistReadingLibrary()
    }

    func startOrResume() {
        if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
            isSpeaking = true
            return
        }

        if isSpeaking {
            pause()
            return
        }

        let visibleStart = pages[safe: currentPage]?.fragments.first
        let index = visibleStart?.paragraphIndex
            ?? currentParagraphIndex
            ?? document.paragraphs.first?.index
        if let index {
            startSpeaking(
                at: index,
                characterOffset: visibleStart?.range.location ?? 0
            )
        }
    }

    func startSpeaking(at paragraphIndex: Int, characterOffset: Int = 0) {
        guard document.paragraphs.indices.contains(paragraphIndex) else { return }
        guard prepareSelectedVoiceForSpeech() else { return }

        if synthesizer.isSpeaking || synthesizer.isPaused {
            shouldContinueAfterFinish = false
            synthesizer.stopSpeaking(at: .immediate)
        }

        currentParagraphIndex = paragraphIndex
        highlightedRange = nil
        isFollowingSpeech = autoFollowSpeech
        pendingSpeechOffset = max(characterOffset, 0)
        moveToPage(
            containing: paragraphIndex,
            characterOffset: pendingSpeechOffset
        )
        updateStopBoundary(for: paragraphIndex)
        speakCurrentSegment()
    }

    func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
        isSpeaking = false
    }

    func stop() {
        shouldContinueAfterFinish = false
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        highlightedRange = nil
        activeSpeechMappings = []
        activeUtteranceID = nil
        isFollowingSpeech = autoFollowSpeech
    }

    func nextParagraph() {
        guard !document.paragraphs.isEmpty else { return }
        let index = min(
            (currentParagraphIndex ?? -1) + 1,
            document.paragraphs.count - 1
        )
        startSpeaking(at: index)
    }

    func previousParagraph() {
        guard !document.paragraphs.isEmpty else { return }
        let index = max((currentParagraphIndex ?? 1) - 1, 0)
        startSpeaking(at: index)
    }

    func showNextPage() {
        guard currentPage + 1 < pages.count else { return }
        suspendSpeechFollowingForManualPaging()
        pageTurnDirection = .next
        currentPage += 1
        syncChapterSelectionToVisiblePage()
    }

    func showPreviousPage() {
        guard currentPage > 0 else { return }
        suspendSpeechFollowingForManualPaging()
        pageTurnDirection = .previous
        currentPage -= 1
        syncChapterSelectionToVisiblePage()
    }

    func resumeFollowingSpeech() {
        guard let paragraphIndex = currentParagraphIndex else { return }
        isFollowingSpeech = true
        moveToPage(
            containing: paragraphIndex,
            characterOffset: highlightedRange?.location ?? 0
        )
    }

    func updateAutoFollowSpeech(_ enabled: Bool) {
        autoFollowSpeech = enabled
        defaults.set(enabled, forKey: autoFollowSpeechKey)
        if enabled, isSpeaking || isPaused {
            resumeFollowingSpeech()
        } else {
            isFollowingSpeech = false
        }
    }

    func selectPreviousChapter() {
        guard !document.chapters.isEmpty else { return }
        selectChapter(max(selectedChapterIndex - 1, 0))
    }

    func selectNextChapter() {
        guard !document.chapters.isEmpty else { return }
        selectChapter(
            min(selectedChapterIndex + 1, document.chapters.count - 1)
        )
    }

    func selectChapter(_ chapterIndex: Int) {
        guard let chapter = document.chapters.first(where: {
            $0.index == chapterIndex
        }) else {
            return
        }

        stop()
        selectedChapterIndex = chapter.index
        currentParagraphIndex = chapter.startParagraphIndex
        highlightedRange = nil
        moveToPage(containing: chapter.startParagraphIndex)
        updateStopBoundary(for: chapter.startParagraphIndex)
        saveProgress(chapter.startParagraphIndex)
    }

    func updateVoice(_ id: String) {
        guard voices.contains(where: { $0.id == id }) else { return }
        previewSynthesizer.stopSpeaking(at: .immediate)
        selectedVoiceID = id
        defaults.set(id, forKey: voiceKey)
    }

    func refreshVoices() {
        let refreshed = Self.availableVoiceOptions()
        guard !refreshed.isEmpty else { return }
        personalVoiceAccessState = Self.personalVoiceAccessState(
            from: AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        )
        voices = refreshed
        favoriteVoiceIDs.formIntersection(Set(refreshed.map(\.id)))
        defaults.set(Array(favoriteVoiceIDs).sorted(), forKey: favoriteVoicesKey)

        guard !refreshed.contains(where: { $0.id == selectedVoiceID }) else {
            return
        }
        let fallback = refreshed.first {
            $0.language == "zh-CN" || $0.language == "zh-Hans"
        } ?? refreshed[0]
        updateVoice(fallback.id)
    }

    func toggleFavoriteVoice(_ id: String) {
        guard voices.contains(where: { $0.id == id }) else { return }
        if favoriteVoiceIDs.contains(id) {
            favoriteVoiceIDs.remove(id)
        } else {
            favoriteVoiceIDs.insert(id)
        }
        defaults.set(Array(favoriteVoiceIDs).sorted(), forKey: favoriteVoicesKey)
    }

    func previewVoice(_ id: String) {
        guard let option = voices.first(where: { $0.id == id }) else {
            errorMessage = "该音色已不可用，请刷新音色列表。"
            return
        }
        guard let voice = resolvedSpeechVoice(identifier: id) else {
            errorMessage = option.isPersonal
                ? "无法调用该个人声音。请确认已在系统设置中允许“声页”使用个人声音，然后返回刷新音色。"
                : "该音色当前不可用，请在系统设置中重新下载后刷新音色。"
            return
        }
        previewSynthesizer.stopSpeaking(at: .immediate)
        let sample = option.language.hasPrefix("zh")
            ? "欢迎使用声页。愿每一次阅读，都自然、清晰而从容。"
            : "Welcome to VoicePage. Enjoy a clear and natural reading experience."
        let utterance = AVSpeechUtterance(string: sample)
        utterance.voice = voice
        utterance.rate = min(max(speechRate, 0.38), 0.52)
        previewSynthesizer.speak(utterance)
    }

    func stopVoicePreview() {
        previewSynthesizer.stopSpeaking(at: .immediate)
    }

    func openVoiceManagement() {
        let accessibilityURL = URL(
            string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent"
        )
        if let accessibilityURL,
           NSWorkspace.shared.open(accessibilityURL) {
            return
        }
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
    }

    func openPersonalVoiceSettings() {
        let personalVoiceURL = URL(
            string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?PersonalVoice"
        )
        if let personalVoiceURL,
           NSWorkspace.shared.open(personalVoiceURL) {
            return
        }
        openVoiceManagement()
    }

    func requestPersonalVoiceAccess() {
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization {
            [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.personalVoiceAccessState = Self.personalVoiceAccessState(
                    from: status
                )
                self.refreshVoices()
            }
        }
    }

    func updateRate(_ rate: Float) {
        speechRate = rate
        defaults.set(rate, forKey: rateKey)
    }

    func updateTheme(_ theme: ThemePreference) {
        themePreference = theme
        defaults.set(theme.rawValue, forKey: themeKey)
    }

    func updateFontSize(_ size: Double) {
        let anchor = paginationAnchor()
        fontSize = min(max(size, 15), 34)
        defaults.set(fontSize, forKey: fontSizeKey)
        rebuildPages()
        moveToPage(
            containing: anchor.paragraphIndex,
            characterOffset: anchor.characterOffset
        )
    }

    func updatePageLayout(width: Double, height: Double) {
        let newLayout = ReaderPageLayout(
            width: max(width.rounded(), 160),
            height: max(height.rounded(), 140)
        )
        guard abs(newLayout.width - pageLayout.width) >= 2
            || abs(newLayout.height - pageLayout.height) >= 2 else {
            return
        }

        let anchor = paginationAnchor()
        pageLayout = newLayout
        rebuildPages()
        moveToPage(
            containing: anchor.paragraphIndex,
            characterOffset: anchor.characterOffset
        )
    }

    func updateBrightness(_ brightness: Double) {
        pageBrightness = min(max(brightness, 0.35), 1)
        defaults.set(pageBrightness, forKey: brightnessKey)
    }

    func updateEyeCareMode(_ enabled: Bool) {
        eyeCareMode = enabled
        defaults.set(enabled, forKey: eyeCareKey)
    }

    private func registerInLibrary(_ newDocument: ReadingDocument) {
        guard let sourceURL = newDocument.sourceURL else { return }
        let standardizedPath = sourceURL.standardizedFileURL.path
        let now = Date()
        if let index = libraryBooks.firstIndex(where: {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path
                == standardizedPath
        }) {
            libraryBooks[index].title = newDocument.title
            libraryBooks[index].path = standardizedPath
            libraryBooks[index].fileExtension = sourceURL.pathExtension.lowercased()
            libraryBooks[index].lastOpenedAt = now
            if let bookmark = readingLibraryStore.makeBookmark(for: sourceURL) {
                libraryBooks[index].bookmarkData = bookmark
            }
        } else {
            libraryBooks.append(
                LibraryBook(
                    id: UUID(),
                    title: newDocument.title,
                    path: standardizedPath,
                    fileExtension: sourceURL.pathExtension.lowercased(),
                    addedAt: now,
                    lastOpenedAt: now,
                    bookmarkData: readingLibraryStore.makeBookmark(for: sourceURL)
                )
            )
        }
        sortReadingLibrary()
        persistReadingLibrary()
        if let book = libraryBooks.first(where: {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path
                == standardizedPath
        }) {
            loadBookCover(for: book)
        }
    }

    private func migrateLegacyProgressIfNeeded() {
        guard libraryBooks.isEmpty,
              let progress = defaults.dictionary(forKey: progressKey) as? [String: Int],
              !progress.isEmpty else {
            return
        }
        let now = Date()
        for (offset, path) in progress.keys.sorted().enumerated() {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            libraryBooks.append(
                LibraryBook(
                    id: UUID(),
                    title: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    fileExtension: url.pathExtension.lowercased(),
                    addedAt: now.addingTimeInterval(TimeInterval(-offset)),
                    lastOpenedAt: now.addingTimeInterval(TimeInterval(-offset)),
                    bookmarkData: readingLibraryStore.makeBookmark(for: url)
                )
            )
        }
        sortReadingLibrary()
        persistReadingLibrary()
    }

    private func sortReadingLibrary() {
        libraryBooks.sort { $0.lastOpenedAt > $1.lastOpenedAt }
        readingHistory.sort { $0.viewedAt > $1.viewedAt }
    }

    private func persistReadingLibrary() {
        readingLibraryStore.save(
            ReadingLibrarySnapshot(
                books: libraryBooks,
                history: readingHistory
            )
        )
    }

    private func refreshBookCovers() {
        for book in libraryBooks {
            loadBookCover(for: book)
        }
    }

    private func loadBookCover(for book: LibraryBook) {
        guard bookCoverImages[book.id] == nil,
              book.fileExtension.lowercased() == "epub" else {
            return
        }

        let bookID = book.id
        let fileExtension = book.fileExtension
        let sourceURL = readingLibraryStore.resolveURL(for: book)
        Task { [weak self] in
            let data = await Task.detached(priority: .utility) {
                BookCoverStore.coverData(
                    bookID: bookID,
                    sourceURL: sourceURL,
                    fileExtension: fileExtension
                )
            }.value
            guard let data, let image = NSImage(data: data) else { return }
            self?.bookCoverImages[bookID] = image
        }
    }

    func annotations(for paragraphIndex: Int) -> [TextAnnotation] {
        annotations.filter { $0.paragraphIndex == paragraphIndex }
    }

    func annotation(
        for paragraphIndex: Int,
        exactly range: NSRange
    ) -> TextAnnotation? {
        annotations.first {
            $0.paragraphIndex == paragraphIndex
                && $0.range.nsRange == range
        }
    }

    func saveAnnotation(
        id: UUID? = nil,
        for paragraphIndex: Int,
        range: NSRange,
        note: String,
        highlightColor: ParagraphHighlightColor?,
        isUnderlined: Bool
    ) {
        guard let paragraph = document.paragraphs[safe: paragraphIndex],
              range.location >= 0,
              range.length > 0,
              NSMaxRange(range) <= (paragraph.text as NSString).length else {
            return
        }
        let selectedText = (paragraph.text as NSString).substring(with: range)
        let existingIndex = annotations.firstIndex {
            if let id {
                return $0.id == id
            }
            return $0.paragraphIndex == paragraphIndex
                && $0.range.nsRange == range
        }
        let annotation = TextAnnotation(
            id: existingIndex.map { annotations[$0].id } ?? id ?? UUID(),
            paragraphIndex: paragraphIndex,
            range: AnnotationTextRange(range),
            selectedText: selectedText,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            highlightColor: highlightColor,
            isUnderlined: isUnderlined,
            modifiedAt: Date()
        )
        if annotation.isEmpty {
            if let existingIndex {
                annotations.remove(at: existingIndex)
            }
        } else if let existingIndex {
            annotations[existingIndex] = annotation
        } else {
            annotations.append(annotation)
        }
        sortAnnotations()
        annotationStore.save(annotations, for: document)
    }

    func setHighlight(
        for paragraphIndex: Int,
        range: NSRange,
        color: ParagraphHighlightColor?
    ) {
        let existing = annotation(for: paragraphIndex, exactly: range)
        saveAnnotation(
            id: existing?.id,
            for: paragraphIndex,
            range: range,
            note: existing?.note ?? "",
            highlightColor: color,
            isUnderlined: existing?.isUnderlined ?? false
        )
    }

    func toggleUnderline(for paragraphIndex: Int, range: NSRange) {
        let existing = annotation(for: paragraphIndex, exactly: range)
        saveAnnotation(
            id: existing?.id,
            for: paragraphIndex,
            range: range,
            note: existing?.note ?? "",
            highlightColor: existing?.highlightColor,
            isUnderlined: !(existing?.isUnderlined ?? false)
        )
    }

    func clearNote(for paragraphIndex: Int, range: NSRange) {
        guard let existing = annotation(
            for: paragraphIndex,
            exactly: range
        ) else {
            return
        }
        saveAnnotation(
            id: existing.id,
            for: paragraphIndex,
            range: range,
            note: "",
            highlightColor: existing.highlightColor,
            isUnderlined: existing.isUnderlined
        )
    }

    func removeAnnotation(id: UUID) {
        annotations.removeAll { $0.id == id }
        annotationStore.save(annotations, for: document)
    }

    func setSleepTimer(_ option: SleepTimerOption) {
        timerTask?.cancel()
        timerTask = nil
        timerOption = option
        timerEndDate = nil
        stopBoundaryParagraphIndex = nil

        if option == .endOfSection || option == .endOfChapter {
            let paragraphIndex = currentParagraphIndex
                ?? pages[safe: currentPage]?.paragraphIndices.first
                ?? 0
            updateStopBoundary(for: paragraphIndex)
        }

        guard let minutes = option.minutes else { return }
        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        timerEndDate = endDate

        timerTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.stop()
                self?.timerOption = .off
                self?.timerEndDate = nil
                self?.stopBoundaryParagraphIndex = nil
            } catch {
                return
            }
        }
    }

    func fragments(
        for paragraphIndex: Int,
        on page: ReadingPage
    ) -> [ReadingPageFragment] {
        page.fragments.filter { $0.paragraphIndex == paragraphIndex }
    }

    private func applyDocument(_ newDocument: ReadingDocument) {
        document = newDocument
        currentParagraphIndex = nil
        highlightedRange = nil
        annotations = annotationStore.annotations(for: newDocument)
        sortAnnotations()
        rebuildPages()

        let savedIndex = savedProgress(for: newDocument)
        if let page = pageIndex(containing: savedIndex, characterOffset: 0) {
            currentPage = page
            currentParagraphIndex = savedIndex
            syncChapterSelection(for: savedIndex)
        } else {
            currentPage = 0
            selectedChapterIndex = newDocument.chapters.first?.index ?? 0
        }
    }

    private func rebuildPages() {
        let result = ReadingPaginator.paginate(
            document: document,
            fontSize: fontSize,
            layout: pageLayout
        )

        pages = result
        currentPage = min(currentPage, max(result.count - 1, 0))
        selectedChapterIndex = min(
            selectedChapterIndex,
            max(document.chapters.count - 1, 0)
        )
    }

    private func speakCurrentSegment() {
        guard let index = currentParagraphIndex,
              let segment = makeSpeechSegment(
                startingAt: index,
                characterOffset: pendingSpeechOffset
              ) else {
            stop()
            return
        }

        let utterance = AVSpeechUtterance(string: segment.text)
        utterance.rate = max(
            AVSpeechUtteranceMinimumSpeechRate,
            min(speechRate, AVSpeechUtteranceMaximumSpeechRate)
        )
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.02
        if let voice = resolvedSpeechVoice(identifier: selectedVoiceID) {
            utterance.voice = voice
        } else if !selectedVoiceID.isEmpty {
            errorMessage = currentVoiceIsPersonal
                ? "个人声音当前不可用，请重新授权并刷新音色。"
                : "所选音色当前不可用，已改用系统默认音色。"
        }

        shouldContinueAfterFinish = true
        isPaused = false
        isSpeaking = true
        activeSpeechMappings = segment.mappings
        pendingSpeechOffset = 0
        activeUtteranceID = ObjectIdentifier(utterance)
        synthesizer.speak(utterance)
        saveProgress(index)
    }

    private func makeSpeechSegment(
        startingAt paragraphIndex: Int,
        characterOffset: Int
    ) -> (text: String, mappings: [SpeechParagraphMapping])? {
        let lastAllowedIndex = min(
            stopBoundaryParagraphIndex ?? (document.paragraphs.count - 1),
            document.paragraphs.count - 1
        )
        guard paragraphIndex <= lastAllowedIndex else { return nil }

        var combinedText = ""
        var mappings: [SpeechParagraphMapping] = []
        var index = paragraphIndex

        while index <= lastAllowedIndex, mappings.count < 3 {
            guard let paragraph = document.paragraphs[safe: index] else {
                break
            }
            let nsText = paragraph.text as NSString
            let requestedOffset = index == paragraphIndex
                ? min(max(characterOffset, 0), nsText.length)
                : 0
            let baseOffset = requestedOffset < nsText.length ? requestedOffset : 0
            let piece = nsText.substring(from: baseOffset)
            let pieceLength = (piece as NSString).length

            if !combinedText.isEmpty {
                combinedText.append("\n")
            }
            let mappingStart = (combinedText as NSString).length
            combinedText.append(piece)
            mappings.append(
                SpeechParagraphMapping(
                    paragraphIndex: index,
                    utteranceRange: NSRange(
                        location: mappingStart,
                        length: pieceLength
                    ),
                    paragraphBaseOffset: baseOffset
                )
            )

            if (combinedText as NSString).length >= 1_600 {
                break
            }
            index += 1
        }

        guard !combinedText.isEmpty, !mappings.isEmpty else { return nil }
        return (combinedText, mappings)
    }

    private func handleSpokenRange(
        _ range: NSRange,
        utteranceID: ObjectIdentifier
    ) {
        guard activeUtteranceID == utteranceID else { return }
        guard let mapping = activeSpeechMappings.first(where: {
            let intersection = NSIntersectionRange($0.utteranceRange, range)
            return intersection.location != NSNotFound && intersection.length > 0
        }) else {
            return
        }
        let intersection = NSIntersectionRange(mapping.utteranceRange, range)
        let paragraphRange = NSRange(
            location: mapping.paragraphBaseOffset
                + intersection.location
                - mapping.utteranceRange.location,
            length: intersection.length
        )
        currentParagraphIndex = mapping.paragraphIndex
        highlightedRange = paragraphRange
        if isFollowingSpeech {
            moveToPage(
                containing: mapping.paragraphIndex,
                characterOffset: paragraphRange.location
            )
        }
        saveProgress(mapping.paragraphIndex)
    }

    private func handleFinishedSegment(
        utteranceID: ObjectIdentifier,
        completed: Bool
    ) {
        guard activeUtteranceID == utteranceID else { return }
        let lastParagraphIndex = activeSpeechMappings.last?.paragraphIndex
            ?? currentParagraphIndex
        activeSpeechMappings = []
        activeUtteranceID = nil
        isSpeaking = false
        isPaused = false
        highlightedRange = nil

        guard completed, shouldContinueAfterFinish else { return }
        guard let current = lastParagraphIndex else { return }
        currentParagraphIndex = current
        if let boundary = stopBoundaryParagraphIndex,
           current >= boundary {
            stopBoundaryParagraphIndex = nil
            timerOption = .off
            shouldContinueAfterFinish = false
            return
        }

        let next = current + 1
        guard document.paragraphs.indices.contains(next) else {
            shouldContinueAfterFinish = false
            return
        }

        currentParagraphIndex = next
        pendingSpeechOffset = 0
        if isFollowingSpeech {
            moveToPage(containing: next, characterOffset: 0)
        }
        speakCurrentSegment()
    }

    private static func availableVoiceOptions() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: voice.language,
                    quality: qualityTier(for: voice.quality),
                    gender: voiceGender(for: voice.gender),
                    isPersonal: voice.voiceTraits.contains(.isPersonalVoice)
                )
            }
            .sorted { lhs, rhs in
                if lhs.language.hasPrefix("zh") != rhs.language.hasPrefix("zh") {
                    return lhs.language.hasPrefix("zh")
                }
                if lhs.quality != rhs.quality {
                    return lhs.quality > rhs.quality
                }
                return lhs.displayName.localizedStandardCompare(rhs.displayName)
                    == .orderedAscending
            }
    }

    private func resolvedSpeechVoice(
        identifier: String
    ) -> AVSpeechSynthesisVoice? {
        // Personal Voice instances are authorization-scoped. Reuse the live
        // voice returned by speechVoices() instead of reconstructing it only
        // from its identifier.
        AVSpeechSynthesisVoice.speechVoices().first {
            $0.identifier == identifier
        } ?? AVSpeechSynthesisVoice(identifier: identifier)
    }

    private func prepareSelectedVoiceForSpeech() -> Bool {
        guard currentVoiceIsPersonal else { return true }

        let status = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        personalVoiceAccessState = Self.personalVoiceAccessState(from: status)

        guard status == .authorized else {
            switch status {
            case .notDetermined:
                errorMessage = "使用个人声音前，请在首页打开“录制／使用个人声音”，并允许声页访问。"
            case .denied:
                errorMessage = "个人声音权限未开启。请在系统设置中允许声页使用个人声音。"
            case .unsupported:
                errorMessage = "这台 Mac 或当前系统不支持个人声音。"
            case .authorized:
                break
            @unknown default:
                errorMessage = "个人声音当前不可用，请检查系统设置后重试。"
            }
            return false
        }

        guard resolvedSpeechVoice(identifier: selectedVoiceID) != nil else {
            refreshVoices()
            errorMessage = "没有找到所选个人声音。请确认声音已生成完成，然后刷新音色。"
            return false
        }
        return true
    }

    private static func qualityTier(
        for quality: AVSpeechSynthesisVoiceQuality
    ) -> VoiceQualityTier {
        switch quality {
        case .premium:
            return .premium
        case .enhanced:
            return .enhanced
        default:
            return .standard
        }
    }

    private static func voiceGender(
        for gender: AVSpeechSynthesisVoiceGender
    ) -> VoiceGender {
        switch gender {
        case .female:
            return .female
        case .male:
            return .male
        case .unspecified:
            return .unspecified
        @unknown default:
            return .neutral
        }
    }

    private static func personalVoiceAccessState(
        from status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus
    ) -> PersonalVoiceAccessState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .unsupported:
            return .unsupported
        case .authorized:
            return .authorized
        @unknown default:
            return .unsupported
        }
    }

    private func suspendSpeechFollowingForManualPaging() {
        guard isSpeaking || isPaused else { return }
        isFollowingSpeech = false
    }

    private func sortAnnotations() {
        annotations.sort {
            if $0.paragraphIndex != $1.paragraphIndex {
                return $0.paragraphIndex < $1.paragraphIndex
            }
            if $0.range.location != $1.range.location {
                return $0.range.location < $1.range.location
            }
            return $0.modifiedAt < $1.modifiedAt
        }
    }

    private func moveToPage(
        containing paragraphIndex: Int,
        characterOffset: Int = 0
    ) {
        if let page = pageIndex(
            containing: paragraphIndex,
            characterOffset: characterOffset
        ) {
            if page != currentPage {
                pageTurnDirection = page > currentPage ? .next : .previous
            }
            currentPage = page
        }
        syncChapterSelection(for: paragraphIndex)
    }

    private func pageIndex(
        containing paragraphIndex: Int,
        characterOffset: Int
    ) -> Int? {
        let exactPage = pages.firstIndex { page in
            page.fragments.contains { fragment in
                fragment.paragraphIndex == paragraphIndex
                    && characterOffset >= fragment.range.location
                    && characterOffset < NSMaxRange(fragment.range)
            }
        }
        if let exactPage {
            return exactPage
        }
        return pages.firstIndex {
            $0.fragments.contains { $0.paragraphIndex == paragraphIndex }
        }
    }

    private func syncChapterSelectionToVisiblePage() {
        guard let fragment = pages[safe: currentPage]?.fragments.first else {
            return
        }
        syncChapterSelection(for: fragment.paragraphIndex)
        if !isSpeaking, !isPaused {
            currentParagraphIndex = fragment.paragraphIndex
            saveProgress(fragment.paragraphIndex)
        }
    }

    private func paginationAnchor() -> (
        paragraphIndex: Int,
        characterOffset: Int
    ) {
        if !isFollowingSpeech,
           let fragment = pages[safe: currentPage]?.fragments.first {
            return (fragment.paragraphIndex, fragment.range.location)
        }
        if let paragraphIndex = currentParagraphIndex,
           let highlightedRange {
            return (paragraphIndex, highlightedRange.location)
        }
        if let fragment = pages[safe: currentPage]?.fragments.first {
            return (fragment.paragraphIndex, fragment.range.location)
        }
        return (currentParagraphIndex ?? 0, 0)
    }

    private func syncChapterSelection(for paragraphIndex: Int) {
        guard let chapter = document.chapters.last(where: {
            $0.startParagraphIndex <= paragraphIndex
        }) else {
            selectedChapterIndex = document.chapters.first?.index ?? 0
            return
        }
        selectedChapterIndex = chapter.index
    }

    private func updateStopBoundary(for paragraphIndex: Int) {
        switch timerOption {
        case .endOfSection:
            stopBoundaryParagraphIndex = boundaryAfterCurrentItem(
                paragraphIndex: paragraphIndex,
                starts: document.sections.map(\.startParagraphIndex)
            )
        case .endOfChapter:
            stopBoundaryParagraphIndex = boundaryAfterCurrentItem(
                paragraphIndex: paragraphIndex,
                starts: document.chapters.map(\.startParagraphIndex)
            )
        case .off, .tenMinutes, .twentyMinutes, .thirtyMinutes, .sixtyMinutes:
            break
        }
    }

    private func boundaryAfterCurrentItem(
        paragraphIndex: Int,
        starts: [Int]
    ) -> Int {
        let nextStart = starts.first(where: { $0 > paragraphIndex })
            ?? document.paragraphs.count
        return max(nextStart - 1, paragraphIndex)
    }

    private func refreshSystemStatus() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        clockText = formatter.string(from: Date())

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            if let range = text.range(
                of: #"[0-9]{1,3}%"#,
                options: .regularExpression
            ) {
                batteryText = String(text[range])
            } else if text.localizedCaseInsensitiveContains("AC Power") {
                batteryText = "外接电源"
            } else {
                batteryText = "—"
            }
        } catch {
            batteryText = "—"
        }
    }

    private func installInputMonitor() {
        guard inputMonitor == nil else { return }
        inputMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .scrollWheel]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .scrollWheel {
                return self.handleTrackpadPaging(event)
            }
            return self.handleKeyboardShortcut(event)
        }
    }

    private func handleKeyboardShortcut(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(
            [.command, .option, .control, .shift]
        )

        switch event.keyCode {
        case 101 where modifiers.isEmpty:
            guard screen == .reader else { return event }
            selectNextChapter()
            return nil
        case 98 where modifiers.isEmpty:
            guard screen == .reader else { return event }
            selectPreviousChapter()
            return nil
        case 49 where modifiers.isEmpty:
            guard screen == .reader else { return event }
            startOrResume()
            return nil
        case 123 where modifiers.isEmpty:
            guard screen == .reader else { return event }
            showPreviousPage()
            return nil
        case 124 where modifiers.isEmpty:
            guard screen == .reader else { return event }
            showNextPage()
            return nil
        case 53 where modifiers.isEmpty:
            NSApp.terminate(nil)
            return nil
        default:
            return event
        }
    }

    private func handleTrackpadPaging(_ event: NSEvent) -> NSEvent? {
        guard screen == .reader,
              event.hasPreciseScrollingDeltas else {
            return event
        }

        if !event.momentumPhase.isEmpty {
            return nil
        }

        let direction = trackpadPageGesture.consume(
            horizontalDelta: Double(event.scrollingDeltaX),
            verticalDelta: Double(event.scrollingDeltaY),
            timestamp: event.timestamp,
            began: event.phase.contains(.began),
            ended: event.phase.contains(.ended)
                || event.phase.contains(.cancelled)
        )

        switch direction {
        case .previous:
            showPreviousPage()
        case .next:
            showNextPage()
        case nil:
            break
        }

        let isHorizontal = abs(event.scrollingDeltaX)
            > abs(event.scrollingDeltaY) * 1.15
        return isHorizontal ? nil : event
    }

    private func saveProgress(_ paragraphIndex: Int) {
        guard let path = document.sourceURL?.path else { return }
        var progress = defaults.dictionary(forKey: progressKey) as? [String: Int] ?? [:]
        if progress[path] != paragraphIndex {
            progress[path] = paragraphIndex
            defaults.set(progress, forKey: progressKey)
        }

        guard let bookIndex = libraryBooks.firstIndex(where: {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path
                == URL(fileURLWithPath: path).standardizedFileURL.path
        }) else {
            return
        }

        let safeIndex = min(
            max(paragraphIndex, 0),
            max(document.paragraphs.count - 1, 0)
        )
        let chapterTitle = document.chapters.last(where: {
            $0.startParagraphIndex <= safeIndex
        })?.title ?? "全文"
        let percentage = document.paragraphs.isEmpty
            ? 0
            : Int(
                (Double(safeIndex + 1)
                    / Double(document.paragraphs.count) * 100).rounded()
            )
        let now = Date()
        let bookID = libraryBooks[bookIndex].id
        if let existing = readingHistory.first(where: { $0.bookID == bookID }),
           existing.paragraphIndex == safeIndex,
           now.timeIntervalSince(existing.viewedAt) < 15 {
            return
        }
        libraryBooks[bookIndex].lastOpenedAt = now

        let entry = ReadingHistoryEntry(
            id: bookID,
            bookID: bookID,
            title: document.title,
            path: path,
            paragraphIndex: safeIndex,
            chapterTitle: chapterTitle,
            progressPercentage: min(max(percentage, 0), 100),
            viewedAt: now
        )
        readingHistory.removeAll { $0.bookID == bookID }
        readingHistory.insert(entry, at: 0)
        sortReadingLibrary()
        persistReadingLibrary()
    }

    private func savedProgress(for document: ReadingDocument) -> Int {
        guard let path = document.sourceURL?.path else { return 0 }
        let progress = defaults.dictionary(forKey: progressKey) as? [String: Int]
        return min(
            max(progress?[path] ?? 0, 0),
            max(document.paragraphs.count - 1, 0)
        )
    }
}

extension ReaderViewModel: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        DispatchQueue.main.async { [weak self] in
            self?.handleSpokenRange(characterRange, utteranceID: utteranceID)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        DispatchQueue.main.async { [weak self] in
            self?.handleFinishedSegment(
                utteranceID: utteranceID,
                completed: true
            )
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        DispatchQueue.main.async { [weak self] in
            self?.handleFinishedSegment(
                utteranceID: utteranceID,
                completed: false
            )
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
