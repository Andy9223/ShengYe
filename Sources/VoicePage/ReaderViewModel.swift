import AppKit
import AVFoundation
import Foundation

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

    let voices: [VoiceOption]

    private let synthesizer = AVSpeechSynthesizer()
    private var timerTask: Task<Void, Never>?
    private var stopBoundaryParagraphIndex: Int?
    private var shouldContinueAfterFinish = false
    private var activeUtteranceID: ObjectIdentifier?
    private var utteranceBaseOffset = 0
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

    override init() {
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .map {
                VoiceOption(
                    id: $0.identifier,
                    name: $0.name,
                    language: $0.language
                )
            }
            .sorted {
                if $0.language.hasPrefix("zh") != $1.language.hasPrefix("zh") {
                    return $0.language.hasPrefix("zh")
                }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }

        voices = availableVoices

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

        super.init()
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

    func openDocument(_ url: URL) {
        stop()
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedDocument = try await Task.detached(priority: .userInitiated) {
                    try DocumentLoader.load(from: url)
                }.value
                applyDocument(loadedDocument)
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

        if synthesizer.isSpeaking || synthesizer.isPaused {
            shouldContinueAfterFinish = false
            synthesizer.stopSpeaking(at: .immediate)
        }

        currentParagraphIndex = paragraphIndex
        highlightedRange = nil
        pendingSpeechOffset = max(characterOffset, 0)
        moveToPage(
            containing: paragraphIndex,
            characterOffset: pendingSpeechOffset
        )
        updateStopBoundary(for: paragraphIndex)
        speakCurrentParagraph()
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
        pageTurnDirection = .next
        currentPage += 1
        syncChapterSelectionToVisiblePage()
    }

    func showPreviousPage() {
        guard currentPage > 0 else { return }
        pageTurnDirection = .previous
        currentPage -= 1
        syncChapterSelectionToVisiblePage()
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
        selectedVoiceID = id
        defaults.set(id, forKey: voiceKey)
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

    private func speakCurrentParagraph() {
        guard let index = currentParagraphIndex,
              let paragraph = document.paragraphs[safe: index] else {
            stop()
            return
        }

        let nsText = paragraph.text as NSString
        let requestedOffset = min(max(pendingSpeechOffset, 0), nsText.length)
        let startOffset = requestedOffset < nsText.length ? requestedOffset : 0
        let speechText = nsText.substring(from: startOffset)
        let utterance = AVSpeechUtterance(string: speechText)
        utterance.rate = max(
            AVSpeechUtteranceMinimumSpeechRate,
            min(speechRate, AVSpeechUtteranceMaximumSpeechRate)
        )
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.08
        if let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceID) {
            utterance.voice = voice
        }

        shouldContinueAfterFinish = true
        isPaused = false
        isSpeaking = true
        utteranceBaseOffset = startOffset
        pendingSpeechOffset = 0
        activeUtteranceID = ObjectIdentifier(utterance)
        synthesizer.speak(utterance)
        saveProgress(index)
    }

    private func handleSpokenRange(
        _ range: NSRange,
        utteranceID: ObjectIdentifier
    ) {
        guard activeUtteranceID == utteranceID else { return }
        highlightedRange = NSRange(
            location: utteranceBaseOffset + range.location,
            length: range.length
        )
        if let paragraphIndex = currentParagraphIndex {
            moveToPage(
                containing: paragraphIndex,
                characterOffset: utteranceBaseOffset + range.location
            )
        }
    }

    private func handleFinishedParagraph(
        utteranceID: ObjectIdentifier,
        completed: Bool
    ) {
        guard activeUtteranceID == utteranceID else { return }
        activeUtteranceID = nil
        isSpeaking = false
        isPaused = false
        highlightedRange = nil

        guard completed, shouldContinueAfterFinish else { return }
        guard let current = currentParagraphIndex else { return }
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
        moveToPage(containing: next, characterOffset: 0)
        speakCurrentParagraph()
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
        progress[path] = paragraphIndex
        defaults.set(progress, forKey: progressKey)
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
            self?.handleFinishedParagraph(
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
            self?.handleFinishedParagraph(
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
