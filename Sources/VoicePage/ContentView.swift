import AppKit
import AVFoundation
import SwiftUI
import Translation
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: ReaderViewModel
    @State private var isImporting = false
    @State private var isFullScreen = false
    @State private var isShowingShortcutGuide = false
    @State private var isShowingVoiceLibrary = false
    @State private var isShowingPersonalVoiceGuide = false
    @State private var isShowingVoiceCenter = false
    @State private var isShowingBookshelf = false
    @State private var isSelectingHistory = false
    @State private var selectedHistoryIDs: Set<UUID> = []
    @State private var annotationTarget: TextSelectionTarget?
    @State private var translationText = ""
    @State private var isShowingTranslation = false

    var body: some View {
        Group {
            switch model.screen {
            case .library:
                if isShowingBookshelf {
                    bookshelfView
                } else {
                    libraryView
                }
            case .reader:
                readerView
            }
        }
        .preferredColorScheme(
            model.eyeCareMode ? .light : model.themePreference.colorScheme
        )
        .environment(\.locale, Locale(identifier: model.appLanguage.rawValue))
        .voicePageTranslationPresentation(
            isPresented: $isShowingTranslation,
            text: translationText
        )
        .frame(minWidth: 780, minHeight: 620)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    model.openDocument(url)
                }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .alert(
            model.localized(.alertTitle),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            actions: {
                Button(model.localized(.ok)) { model.errorMessage = nil }
            },
            message: {
                Text(model.errorMessage ?? model.localized(.unknownError))
            }
        )
        .sheet(isPresented: $isShowingShortcutGuide) {
            ShortcutGuideView()
        }
        .sheet(isPresented: $isShowingVoiceLibrary) {
            VoiceLibraryView()
                .environmentObject(model)
        }
        .sheet(isPresented: $isShowingPersonalVoiceGuide) {
            PersonalVoiceGuideView()
                .environmentObject(model)
        }
        .sheet(isPresented: $isShowingVoiceCenter) {
            VoiceCenterView(
                onOpenVoiceLibrary: {
                    isShowingVoiceCenter = false
                    DispatchQueue.main.async {
                        isShowingVoiceLibrary = true
                    }
                },
                onOpenPersonalVoiceGuide: {
                    isShowingVoiceCenter = false
                    DispatchQueue.main.async {
                        isShowingPersonalVoiceGuide = true
                    }
                }
            )
            .environmentObject(model)
        }
        .sheet(item: $annotationTarget) { target in
            ParagraphAnnotationEditor(
                selectedText: target.selectedText,
                annotation: model.annotation(
                    for: target.paragraphIndex,
                    exactly: target.range
                ),
                onSave: { note, color, isUnderlined in
                    model.saveAnnotation(
                        id: target.annotationID,
                        for: target.paragraphIndex,
                        range: target.range,
                        note: note,
                        highlightColor: color,
                        isUnderlined: isUnderlined
                    )
                    annotationTarget = nil
                },
                onDelete: {
                    if let annotationID = target.annotationID {
                        model.removeAnnotation(id: annotationID)
                    }
                    annotationTarget = nil
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBook)) { _ in
            model.returnToLibrary()
            isShowingBookshelf = false
            isImporting = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSpeech)) { _ in
            if model.screen == .reader {
                model.startOrResume()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .onAppear {
            isFullScreen = NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            model.refreshVoices()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: AVSpeechSynthesizer.availableVoicesDidChangeNotification
            )
        ) { _ in
            model.refreshVoices()
        }
    }

    private var libraryView: some View {
        ZStack {
            readerBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) {
                            libraryBrand
                            Spacer(minLength: 16)
                            libraryHeaderActions
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            libraryBrand
                            libraryHeaderActions
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    if model.isLoading {
                        ProgressView(model.localized(.organizingBook))
                            .controlSize(.large)
                            .frame(height: 110)
                    } else {
                        if let lastReading = model.lastReadingHistory {
                            Button {
                                model.openLastReadingProgress()
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.accentColor)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.localized(.continueReading))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(lastReading.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(
                                            "\(lastReading.chapterTitle) · \(lastReading.progressPercentage)%"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(
                                Color.accentColor.opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.accentColor.opacity(0.18))
                            }
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 350), spacing: 16)
                            ],
                            alignment: .leading,
                            spacing: 16
                        ) {
                            myBooksShortcut
                            viewingHistoryCard
                        }
                    }
                }
                .frame(maxWidth: 1_060)
                .padding(.horizontal, 32)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var libraryBrand: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 66, height: 66)

            Text(model.localized(.appName))
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var libraryHeaderActions: some View {
        HStack(spacing: 10) {
            Picker(
                selection: Binding(
                    get: { model.appLanguage },
                    set: { model.updateAppLanguage($0) }
                ),
                label: Label(
                    model.localized(.language),
                    systemImage: "globe"
                )
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            Button {
                isShowingShortcutGuide = true
            } label: {
                Label(
                    model.localized(.shortcutGuide),
                    systemImage: "keyboard"
                )
            }

            Button {
                isShowingVoiceCenter = true
            } label: {
                Label(
                    model.localized(.voiceCenter),
                    systemImage: "waveform.badge.plus"
                )
            }

            Button {
                isImporting = true
            } label: {
                Label(model.localized(.importBook), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var myBooksShortcut: some View {
        Button {
            isShowingBookshelf = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 46, height: 46)
                    .background(
                        Color.accentColor.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.localized(.myBooks))
                        .font(.headline)
                    Text(
                        model.libraryBooks.isEmpty
                            ? model.localized(.openBookshelfAndImport)
                            : model.localized(.bookCount, model.libraryBooks.count)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.secondary.opacity(0.1))
        }
    }

    private var viewingHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.localized(.viewingHistory), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()

                if !model.readingHistory.isEmpty {
                    if isSelectingHistory {
                        Button(
                            selectedHistoryIDs.count == model.readingHistory.count
                                ? model.localized(.deselectAll)
                                : model.localized(.selectAll)
                        ) {
                            if selectedHistoryIDs.count == model.readingHistory.count {
                                selectedHistoryIDs.removeAll()
                            } else {
                                selectedHistoryIDs = Set(model.readingHistory.map(\.id))
                            }
                        }

                        Button(model.localized(.deleteSelected)) {
                            model.removeHistory(ids: selectedHistoryIDs)
                            selectedHistoryIDs.removeAll()
                            isSelectingHistory = false
                        }
                        .disabled(selectedHistoryIDs.isEmpty)
                    }

                    Button(
                        isSelectingHistory
                            ? model.localized(.done)
                            : model.localized(.batchManage)
                    ) {
                        isSelectingHistory.toggle()
                        if !isSelectingHistory {
                            selectedHistoryIDs.removeAll()
                        }
                    }
                }
            }

            Divider()

            if model.readingHistory.isEmpty {
                HomeEmptyState(
                    icon: "clock",
                    title: model.localized(.noHistory),
                    detail: model.localized(.historyWillAppear)
                )
            } else {
                ForEach(ReadingHistoryPeriod.allCases) { period in
                    let entries = model.readingHistory.filter {
                        ReadingHistoryPeriod.period(for: $0.viewedAt) == period
                    }
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(period.localizedTitle(language: model.appLanguage))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.14))
                                    .frame(height: 1)
                            }

                            ForEach(entries) { entry in
                                HomeHistoryRow(
                                    entry: entry,
                                    language: model.appLanguage,
                                    isSelecting: isSelectingHistory,
                                    isSelected: selectedHistoryIDs.contains(entry.id),
                                    onOpen: { model.openHistoryEntry(entry) },
                                    onToggleSelection: {
                                        if selectedHistoryIDs.contains(entry.id) {
                                            selectedHistoryIDs.remove(entry.id)
                                        } else {
                                            selectedHistoryIDs.insert(entry.id)
                                        }
                                    },
                                    onDelete: {
                                        model.removeHistory(ids: [entry.id])
                                        selectedHistoryIDs.remove(entry.id)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var bookshelfView: some View {
        ZStack {
            readerBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Button {
                        isShowingBookshelf = false
                    } label: {
                        Label(model.localized(.back), systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .help(model.localized(.backHome))

                    Image(systemName: "books.vertical.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.localized(.myBooks))
                            .font(.title2.bold())
                        Text(model.localized(.shelfBookCount, model.libraryBooks.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isImporting = true
                    } label: {
                        Label(model.localized(.importBook), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.ultraThinMaterial)

                Divider().opacity(0.5)

                if model.libraryBooks.isEmpty {
                    ContentUnavailableView {
                        Label(model.localized(.emptyShelf), systemImage: "books.vertical")
                    } description: {
                        Text(model.localized(.importedBooksStayLocal))
                    } actions: {
                        Button(model.localized(.importFirstBook)) {
                            isImporting = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(minimum: 165, maximum: 205),
                                    spacing: 28,
                                    alignment: .top
                                )
                            ],
                            alignment: .leading,
                            spacing: 30
                        ) {
                            ForEach(model.libraryBooks) { book in
                                BookshelfBookItem(
                                    book: book,
                                    coverImage: model.bookCoverImage(for: book.id),
                                    history: model.historyEntry(for: book.id),
                                    language: model.appLanguage,
                                    onOpen: { model.openLibraryBook(book) },
                                    onRemove: {
                                        model.removeLibraryBook(id: book.id)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 30)
                    }
                }
            }
        }
    }

    private var readerView: some View {
        ZStack(alignment: .trailing) {
            readerBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                readerHeader
                Divider().opacity(0.5)
                readerPage
                readerFooter
            }

            floatingSettings
                .padding(.trailing, 18)
        }
    }

    private var readerHeader: some View {
        HStack(spacing: 16) {
            Button {
                model.returnToLibrary()
            } label: {
                Label(model.localized(.back), systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help(model.localized(.backBookshelf))

            VStack(alignment: .leading, spacing: 3) {
                Text(model.document.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(model.isSpeaking ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker(
                selection: Binding(
                    get: { model.selectedChapterIndex },
                    set: { model.selectChapter($0) }
                ),
                label: Label(model.localized(.chapter), systemImage: "list.bullet.rectangle")
            ) {
                ForEach(model.document.chapters) { chapter in
                    Text(chapter.title).tag(chapter.index)
                }
            }
            .pickerStyle(.menu)
            .frame(width: min(isFullScreen ? 380 : 280, 380))
            .help(model.localized(.chooseChapter))
        }
        .padding(.horizontal, isFullScreen ? 38 : 26)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var readerPage: some View {
        if model.isLoading {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(model.localized(.organizingParagraphs))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let page = model.pages[safe: model.currentPage] {
            GeometryReader { geometry in
                let adaptiveWidth = min(
                    max(geometry.size.width * (isFullScreen ? 0.82 : 0.76), 620),
                    1_280
                )
                let verticalPadding = isFullScreen ? 46.0 : 30.0
                let textWidth = max(adaptiveWidth - 32, 160)
                let textHeight = max(
                    geometry.size.height - verticalPadding * 2,
                    140
                )

                ZStack {
                    readerBackground

                    VStack(alignment: .leading, spacing: model.fontSize * 0.7) {
                        ForEach(page.paragraphIndices, id: \.self) { paragraphIndex in
                            if let paragraph = model.document.paragraphs[
                                safe: paragraphIndex
                            ] {
                                ParagraphView(
                                    paragraph: paragraph,
                                    fragments: model.fragments(
                                        for: paragraphIndex,
                                        on: page
                                    ),
                                    isCurrent: model.currentParagraphIndex == paragraph.index,
                                    highlightedRange: model.currentParagraphIndex == paragraph.index
                                        ? model.highlightedRange
                                        : nil,
                                    annotations: model.annotations(
                                        for: paragraph.index
                                    ),
                                    fontSize: model.fontSize,
                                    language: model.appLanguage,
                                    onSpeak: { sentenceOffset in
                                    model.startSpeaking(
                                        at: paragraph.index,
                                        characterOffset: sentenceOffset
                                    )
                                },
                                    onSelectionCommand: {
                                        command,
                                        range,
                                        selectedText in
                                        handleSelectionCommand(
                                            command,
                                            paragraphIndex: paragraph.index,
                                            range: range,
                                            selectedText: selectedText
                                        )
                                    }
                                )
                            }
                        }
                    }
                    .frame(
                        width: adaptiveWidth,
                        height: textHeight,
                        alignment: .topLeading
                    )
                    .padding(.vertical, verticalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .id("\(page.id)-\(Int(model.fontSize))-\(Int(textWidth))x\(Int(textHeight))")
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: pageInsertionEdge)
                                .combined(with: .opacity),
                            removal: .move(edge: pageRemovalEdge)
                                .combined(with: .opacity)
                        )
                    )
                    .animation(
                        .easeInOut(duration: 0.28),
                        value: model.currentPage
                    )

                    Color.black
                        .opacity(max(0, 1 - model.pageBrightness))
                        .allowsHitTesting(false)
                }
                .onAppear {
                    model.updatePageLayout(
                        width: textWidth,
                        height: textHeight
                    )
                }
                .onChange(of: geometry.size) { _, _ in
                    model.updatePageLayout(
                        width: textWidth,
                        height: textHeight
                    )
                }
                .onChange(of: isFullScreen) { _, _ in
                    model.updatePageLayout(
                        width: textWidth,
                        height: textHeight
                    )
                }
            }
        } else {
            ContentUnavailableView(
                model.localized(.noReadableText),
                systemImage: "text.book.closed",
                description: Text(model.localized(.openReadableBook))
            )
        }
    }

    private var readerFooter: some View {
        HStack(spacing: 18) {
            Button {
                model.selectPreviousChapter()
            } label: {
                Image(systemName: "backward.end.fill")
                    .frame(width: 24)
            }
            .disabled(model.selectedChapterIndex == 0)
            .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
            .help(model.localized(.previousChapterHelp))

            Button {
                model.showPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24)
            }
            .disabled(model.currentPage == 0)
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .help(model.localized(.previousPageHelp))

            Button {
                model.startOrResume()
            } label: {
                Image(systemName: model.isSpeaking ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 34, height: 28)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.space, modifiers: [])
            .help(
                model.isSpeaking
                    ? model.localized(.pauseReadingHelp)
                    : model.localized(.startReadingHelp)
            )

            if !model.isFollowingSpeech && (model.isSpeaking || model.isPaused) {
                Button {
                    model.resumeFollowingSpeech()
                } label: {
                    Label(model.localized(.returnToSpeech), systemImage: "location.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help(model.localized(.restoreAutoFollow))
            }

            Spacer(minLength: 12)

            if isFullScreen {
                HStack(spacing: 24) {
                    Label(
                        model.localized(.batteryRemaining, model.batteryText),
                        systemImage: "battery.75percent"
                    )
                    Label(model.clockText, systemImage: "clock")
                    Label(
                        model.localized(
                            .progressPercent,
                            model.readingProgressPercentage
                        ),
                        systemImage: "chart.bar.fill"
                    )
                }
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            } else {
                Text("\(model.currentChapterTitle) · \(model.currentPageLabel)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                model.showNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 24)
            }
            .disabled(model.currentPage + 1 >= model.pages.count)
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .help(model.localized(.nextPageHelp))

            Button {
                model.selectNextChapter()
            } label: {
                Image(systemName: "forward.end.fill")
                    .frame(width: 24)
            }
            .disabled(model.selectedChapterIndex + 1 >= model.document.chapters.count)
            .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            .help(model.localized(.nextChapterHelp))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isFullScreen ? 38 : 28)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var floatingSettings: some View {
        HStack(spacing: 0) {
            if model.controlsExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Label(model.localized(.readingSettings), systemImage: "slider.horizontal.3")
                        .font(.headline)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Label(model.localized(.readingVoice), systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            isShowingVoiceLibrary = true
                        } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.currentVoiceName)
                                        .lineLimit(1)
                                    Text(
                                        model.currentVoiceIsPersonal
                                            ? model.localized(.personalVoice)
                                            : model.localized(
                                                .voiceQuality,
                                                model.currentVoiceQuality
                                                    .localizedLabel(
                                                        language: model.appLanguage
                                                    )
                                            )
                                    )
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(width: 196)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.bordered)
                    }

                    settingSlider(
                        title: model.localized(.speechRate),
                        icon: "speedometer",
                        valueText: String(format: "%.0f%%", model.speechRate / 0.5 * 100),
                        value: Binding(
                            get: { Double(model.speechRate) },
                            set: { model.updateRate(Float($0)) }
                        ),
                        range: 0.25...0.62,
                        step: 0.01
                    )

                    settingToggle(
                        title: model.localized(.autoFollow),
                        icon: "rectangle.portrait.on.rectangle.portrait",
                        detail: model.autoFollowSpeech
                            ? model.localized(.autoFollowOnDetail)
                            : model.localized(.autoFollowOffDetail),
                        isOn: Binding(
                            get: { model.autoFollowSpeech },
                            set: { model.updateAutoFollowSpeech($0) }
                        )
                    )

                    settingPicker(
                        title: model.localized(.stopCondition),
                        icon: "moon.zzz",
                        selection: Binding(
                            get: { model.timerOption },
                            set: { model.setSleepTimer($0) }
                        )
                    ) {
                        ForEach(SleepTimerOption.allCases) { option in
                            Text(
                                option.localizedLabel(language: model.appLanguage)
                            )
                            .tag(option)
                        }
                    }

                    settingPicker(
                        title: model.localized(.displayMode),
                        icon: "circle.lefthalf.filled",
                        selection: Binding(
                            get: { model.themePreference },
                            set: { model.updateTheme($0) }
                        )
                    ) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(
                                theme.localizedLabel(language: model.appLanguage)
                            )
                            .tag(theme)
                        }
                    }

                    settingToggle(
                        title: model.localized(.eyeCareMode),
                        icon: "leaf.fill",
                        detail: model.localized(.eyeCareDetail),
                        isOn: Binding(
                            get: { model.eyeCareMode },
                            set: { model.updateEyeCareMode($0) }
                        )
                    )

                    settingSlider(
                        title: model.localized(.fontSize),
                        icon: "textformat.size",
                        valueText: "\(Int(model.fontSize))",
                        value: Binding(
                            get: { model.fontSize },
                            set: { model.updateFontSize($0) }
                        ),
                        range: 15...34,
                        step: 1
                    )

                    settingSlider(
                        title: model.localized(.pageBrightness),
                        icon: "sun.max.fill",
                        valueText: "\(Int(model.pageBrightness * 100))%",
                        value: Binding(
                            get: { model.pageBrightness },
                            set: { model.updateBrightness($0) }
                        ),
                        range: 0.35...1,
                        step: 0.05
                    )

                    Text(model.localized(.selectionHint))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 242, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.white.opacity(0.12))
                }
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    model.controlsExpanded.toggle()
                }
            } label: {
                Image(systemName: model.controlsExpanded ? "chevron.right" : "slider.horizontal.3")
                    .font(model.controlsExpanded ? .body : .title2)
                    .frame(width: model.controlsExpanded ? 34 : 50, height: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .help(
                model.controlsExpanded
                    ? model.localized(.collapseSettings)
                    : model.localized(.expandSettings)
            )
        }
    }

    private func settingPicker<Selection: Hashable, Content: View>(
        title: String,
        icon: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection, content: content)
                .labelsHidden()
                .frame(width: 216)
        }
    }

    private func settingSlider(
        title: String,
        icon: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Slider(value: value, in: range, step: step)
        }
    }

    private func settingToggle(
        title: String,
        icon: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: icon)
                    .font(.caption)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.switch)
    }

    private func handleSelectionCommand(
        _ command: TextSelectionCommand,
        paragraphIndex: Int,
        range: NSRange,
        selectedText: String
    ) {
        switch command {
        case .highlight(let color):
            model.setHighlight(
                for: paragraphIndex,
                range: range,
                color: color
            )
        case .addNote:
            let existing = model.annotation(
                for: paragraphIndex,
                exactly: range
            )
            annotationTarget = TextSelectionTarget(
                paragraphIndex: paragraphIndex,
                range: range,
                selectedText: selectedText,
                annotationID: existing?.id
            )
        case .clearNote:
            model.clearNote(
                for: paragraphIndex,
                range: range
            )
        case .toggleUnderline:
            model.toggleUnderline(
                for: paragraphIndex,
                range: range
            )
        case .translate:
            if #available(macOS 14.4, *) {
                translationText = selectedText
                isShowingTranslation = true
            } else {
                model.errorMessage = model.localized(.translationRequiresNewerSystem)
            }
        }
    }

    private var readerBackground: Color {
        model.eyeCareMode
            ? Color(red: 0.925, green: 0.94, blue: 0.875)
            : Color(nsColor: .textBackgroundColor)
    }

    private var pageInsertionEdge: Edge {
        model.pageTurnDirection == .next ? .trailing : .leading
    }

    private var pageRemovalEdge: Edge {
        model.pageTurnDirection == .next ? .leading : .trailing
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let epub = UTType(filenameExtension: "epub") {
            types.append(epub)
        }
        return types
    }

}

private struct HomeEmptyState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 112)
    }
}

private struct BookshelfBookItem: View {
    let book: LibraryBook
    let coverImage: NSImage?
    let history: ReadingHistoryEntry?
    let language: AppLanguage
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Button(action: onOpen) {
                    BookshelfCover(
                        book: book,
                        image: coverImage,
                        language: language
                    )
                }
                .buttonStyle(.plain)
                .disabled(!book.isAvailable)

                Menu {
                    Button(
                        AppLocalization.text(
                            .removeFromLibrary,
                            language: language
                        ),
                        role: .destructive,
                        action: onRemove
                    )
                    Text(
                        AppLocalization.text(
                            .originalFileKept,
                            language: language
                        )
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 24)
                        .background(.regularMaterial, in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(8)
            }

            Button(action: onOpen) {
                Text(book.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!book.isAvailable)

            HStack(spacing: 5) {
                Text(book.fileExtension.uppercased())
                if let history {
                    Text("·")
                    Text(
                        AppLocalization.format(
                            .progress,
                            language: language,
                            history.progressPercentage
                        )
                    )
                }
                if !book.isAvailable {
                    Text(
                        "· " + AppLocalization.text(
                            .sourceUnavailable,
                            language: language
                        )
                    )
                        .foregroundStyle(.red)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct BookshelfCover: View {
    let book: LibraryBook
    let image: NSImage?
    let language: AppLanguage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: fallbackColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(book.title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                        .minimumScaleFactor(0.76)

                    Spacer(minLength: 0)

                    Text(book.fileExtension.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.horizontal, 17)
                .padding(.vertical, 22)
            }

            if !book.isAvailable {
                Color.black.opacity(0.34)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.69, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.white.opacity(0.18))
        }
        .shadow(color: .black.opacity(0.16), radius: 7, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .help(
            book.isAvailable
                ? AppLocalization.format(
                    .openNamedBook,
                    language: language,
                    book.title
                )
                : AppLocalization.text(
                    .sourceUnavailable,
                    language: language
                )
        )
    }

    private var fallbackColors: [Color] {
        switch stableColorIndex {
        case 0:
            return [
                Color(red: 0.22, green: 0.37, blue: 0.31),
                Color(red: 0.39, green: 0.52, blue: 0.43)
            ]
        case 1:
            return [
                Color(red: 0.42, green: 0.31, blue: 0.25),
                Color(red: 0.67, green: 0.49, blue: 0.34)
            ]
        case 2:
            return [
                Color(red: 0.25, green: 0.32, blue: 0.43),
                Color(red: 0.40, green: 0.49, blue: 0.60)
            ]
        case 3:
            return [
                Color(red: 0.38, green: 0.27, blue: 0.36),
                Color(red: 0.58, green: 0.42, blue: 0.54)
            ]
        default:
            return [
                Color(red: 0.37, green: 0.35, blue: 0.28),
                Color(red: 0.59, green: 0.55, blue: 0.40)
            ]
        }
    }

    private var stableColorIndex: Int {
        book.id.uuidString.unicodeScalars.reduce(0) {
            ($0 + Int($1.value)) % 5
        }
    }
}

private struct HomeHistoryRow: View {
    let entry: ReadingHistoryEntry
    let language: AppLanguage
    let isSelecting: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onToggleSelection: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isSelecting {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: isSelecting ? onToggleSelection : onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Text(
                            entry.viewedAt.formatted(
                                date: .numeric,
                                time: .shortened
                            )
                        )
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 7) {
                        Text(entry.chapterTitle)
                            .lineLimit(1)
                        Text("·")
                        Text("\(entry.progressPercentage)%")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    ProgressView(value: Double(entry.progressPercentage), total: 100)
                        .progressViewStyle(.linear)
                        .controlSize(.mini)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isSelecting {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(
                    AppLocalization.text(
                        .deleteHistoryHelp,
                        language: language
                    )
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TextSelectionTarget: Identifiable {
    let id = UUID()
    let paragraphIndex: Int
    let range: NSRange
    let selectedText: String
    let annotationID: UUID?
}

private extension View {
    @ViewBuilder
    func voicePageTranslationPresentation(
        isPresented: Binding<Bool>,
        text: String
    ) -> some View {
        if #available(macOS 14.4, *) {
            translationPresentation(
                isPresented: isPresented,
                text: text
            )
        } else {
            self
        }
    }
}

private struct VoiceCenterView: View {
    @EnvironmentObject private var model: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    let onOpenVoiceLibrary: () -> Void
    let onOpenPersonalVoiceGuide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(model.localized(.voiceCenter), systemImage: "waveform.circle.fill")
                        .font(.title2.bold())
                    Text(model.localized(.voiceCenterDetail))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.localized(.done)) { dismiss() }
            }

            HStack(spacing: 14) {
                voiceCenterCard(
                    title: model.localized(.installedVoices),
                    detail: model.localized(
                        .currentVoiceDetail,
                        model.currentVoiceName
                    ),
                    icon: "waveform",
                    buttonTitle: model.localized(.chooseReadingVoice),
                    action: onOpenVoiceLibrary
                )

                voiceCenterCard(
                    title: model.localized(.enhancedVoices),
                    detail: model.localized(.enhancedVoicesDetail),
                    icon: "arrow.down.circle",
                    buttonTitle: model.localized(.openSystemVoiceDownloads),
                    action: model.openVoiceManagement
                )

                voiceCenterCard(
                    title: model.localized(.personalVoice),
                    detail: model.localized(
                        .personalVoiceStatusDetail,
                        model.personalVoiceAccessState.localizedLabel(
                            language: model.appLanguage
                        ),
                        model.personalVoiceCount
                    ),
                    icon: "person.wave.2",
                    buttonTitle: model.localized(.recordingAndAuthorization),
                    action: onOpenPersonalVoiceGuide
                )
            }
        }
        .padding(26)
        .frame(width: 790)
    }

    private func voiceCenterCard(
        title: String,
        detail: String,
        icon: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct VoiceLibraryView: View {
    @EnvironmentObject private var model: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var displayedVoices: [VoiceOption] {
        let matching = model.voices.filter { voice in
            guard !searchText.isEmpty else { return true }
            return voice.displayName(language: model.appLanguage)
                .localizedCaseInsensitiveContains(searchText)
                || voice.gender.localizedLabel(language: model.appLanguage)
                    .localizedCaseInsensitiveContains(searchText)
        }
        return matching.sorted { lhs, rhs in
            let lhsFavorite = model.favoriteVoiceIDs.contains(lhs.id)
            let rhsFavorite = model.favoriteVoiceIDs.contains(rhs.id)
            if lhsFavorite != rhsFavorite {
                return lhsFavorite
            }
            if lhs.isPersonal != rhs.isPersonal {
                return lhs.isPersonal
            }
            if lhs.language.hasPrefix("zh") != rhs.language.hasPrefix("zh") {
                return lhs.language.hasPrefix("zh")
            }
            if lhs.quality != rhs.quality {
                return lhs.quality > rhs.quality
            }
            return lhs.displayName(language: model.appLanguage)
                .localizedStandardCompare(
                    rhs.displayName(language: model.appLanguage)
                )
                == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.localized(.localVoiceLibrary))
                        .font(.title2.bold())
                    Text(model.localized(.localVoicePrivacy))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(model.localized(.done)) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Divider()

            List(displayedVoices) { voice in
                VoiceLibraryRow(
                    voice: voice,
                    language: model.appLanguage,
                    isSelected: model.selectedVoiceID == voice.id,
                    isFavorite: model.favoriteVoiceIDs.contains(voice.id),
                    onSelect: {
                        model.updateVoice(voice.id)
                    },
                    onPreview: {
                        model.previewVoice(voice.id)
                    },
                    onToggleFavorite: {
                        model.toggleFavoriteVoice(voice.id)
                    }
                )
            }
            .searchable(
                text: $searchText,
                prompt: model.localized(.searchVoices)
            )
            .overlay {
                if displayedVoices.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }

            Divider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.localized(.wantNaturalVoice))
                        .font(.callout.weight(.medium))
                    Text(model.localized(.downloadVoiceHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.openVoiceManagement()
                } label: {
                    Label(
                        model.localized(.openSystemVoiceManager),
                        systemImage: "arrow.up.forward.app"
                    )
                }

                Button {
                    model.refreshVoices()
                } label: {
                    Label(model.localized(.refresh), systemImage: "arrow.clockwise")
                }
            }
            .padding(18)
        }
        .frame(minWidth: 660, minHeight: 560)
        .onDisappear {
            model.stopVoicePreview()
        }
    }
}

private struct VoiceLibraryRow: View {
    let voice: VoiceOption
    let language: AppLanguage
    let isSelected: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(
                            isSelected
                                ? Color.accentColor
                                : Color.secondary.opacity(0.55)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(voice.name)
                            .font(.body.weight(isSelected ? .semibold : .regular))
                        Text(
                            localizedLanguage
                                + " · "
                                + voice.gender.localizedLabel(
                                    language: language
                                )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(
                voice.isPersonal
                    ? AppLocalization.text(.personalVoice, language: language)
                    : voice.quality.localizedLabel(language: language)
            )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(
                    voice.isPersonal ? Color.green : voice.quality.badgeColor
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (
                        voice.isPersonal
                            ? Color.green
                            : voice.quality.badgeColor
                    ).opacity(0.13),
                    in: Capsule()
                )

            Button(action: onPreview) {
                Image(systemName: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderless)
            .help(AppLocalization.text(.previewVoice, language: language))

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.orange : .secondary)
            }
            .buttonStyle(.borderless)
            .help(
                AppLocalization.text(
                    isFavorite ? .removeFavorite : .addFavorite,
                    language: language
                )
            )
        }
        .padding(.vertical, 4)
    }

    private var localizedLanguage: String {
        Locale(identifier: language.rawValue)
            .localizedString(forIdentifier: voice.language)
            ?? voice.language
    }
}

private struct PersonalVoiceGuideView: View {
    @EnvironmentObject private var model: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.localized(.recordPersonalVoice))
                        .font(.title2.bold())
                    Text(model.localized(.personalRecordingPrivacy))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(model.localized(.done)) {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                personalVoiceStep(
                    number: 1,
                    title: model.localized(.createPersonalVoice),
                    detail: model.localized(.createPersonalVoiceDetail)
                )
                personalVoiceStep(
                    number: 2,
                    title: model.localized(.allowPersonalVoice),
                    detail: model.localized(.allowPersonalVoiceDetail)
                )
                personalVoiceStep(
                    number: 3,
                    title: model.localized(.returnRefreshChoose),
                    detail: model.localized(.returnRefreshChooseDetail)
                )
            }
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Label(
                    model.localized(
                        .currentStatus,
                        model.personalVoiceAccessState.localizedLabel(
                            language: model.appLanguage
                        )
                    ),
                    systemImage: personalVoiceStatusIcon
                )
                .foregroundStyle(personalVoiceStatusColor)

                Spacer()

                if model.personalVoiceCount > 0 {
                    Text(
                        model.localized(
                            .personalVoiceCount,
                            model.personalVoiceCount
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(model.localized(.personalVoiceRequirements))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if model.personalVoiceAccessState != .authorized {
                Label(
                    model.localized(.personalVoiceReauthorization),
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    model.openPersonalVoiceSettings()
                } label: {
                    Label(
                        model.localized(.openPersonalVoiceSettings),
                        systemImage: "arrow.up.forward.app"
                    )
                }

                Spacer()

                Button {
                    model.requestPersonalVoiceAccess()
                } label: {
                    Label(
                        model.personalVoiceAccessState == .authorized
                            ? model.localized(.refreshPersonalVoices)
                            : model.localized(.allowVoicePage),
                        systemImage: "person.badge.key.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.personalVoiceAccessState == .unsupported)
            }
        }
        .padding(26)
        .frame(width: 620)
    }

    private func personalVoiceStep(
        number: Int,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var personalVoiceStatusIcon: String {
        switch model.personalVoiceAccessState {
        case .authorized:
            return "checkmark.circle.fill"
        case .unsupported:
            return "xmark.circle.fill"
        case .denied:
            return "exclamationmark.triangle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        }
    }

    private var personalVoiceStatusColor: Color {
        switch model.personalVoiceAccessState {
        case .authorized:
            return .green
        case .unsupported, .denied:
            return .orange
        case .notDetermined:
            return .secondary
        }
    }
}

private struct ParagraphAnnotationEditor: View {
    @EnvironmentObject private var model: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    let selectedText: String
    let annotation: TextAnnotation?
    let onSave: (String, ParagraphHighlightColor?, Bool) -> Void
    let onDelete: () -> Void

    @State private var note: String
    @State private var highlightColor: ParagraphHighlightColor?
    @State private var isUnderlined: Bool

    init(
        selectedText: String,
        annotation: TextAnnotation?,
        onSave: @escaping (String, ParagraphHighlightColor?, Bool) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.selectedText = selectedText
        self.annotation = annotation
        self.onSave = onSave
        self.onDelete = onDelete
        _note = State(initialValue: annotation?.note ?? "")
        _highlightColor = State(
            initialValue: annotation == nil
                ? ParagraphHighlightColor.yellow
                : annotation?.highlightColor
        )
        _isUnderlined = State(initialValue: annotation?.isUnderlined ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(
                    annotation == nil
                        ? model.localized(.addAnnotation)
                        : model.localized(.editAnnotation),
                    systemImage: "highlighter"
                )
                .font(.title2.bold())
                Spacer()
                Button(model.localized(.cancel)) {
                    dismiss()
                }
            }

            Text(selectedText)
                .font(.system(.body, design: .serif))
                .lineLimit(5)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    highlightColor?.color.opacity(0.24) ?? Color.secondary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .underline(isUnderlined, color: .secondary)

            VStack(alignment: .leading, spacing: 9) {
                Text(model.localized(.highlightColor))
                    .font(.headline)

                HStack(spacing: 12) {
                    annotationColorButton(
                        nil,
                        label: model.localized(.noColor)
                    )
                    ForEach(ParagraphHighlightColor.allCases) { color in
                        annotationColorButton(
                            color,
                            label: color.localizedLabel(
                                language: model.appLanguage
                            )
                        )
                    }
                }
            }

            Toggle(model.localized(.underlineSelection), isOn: $isUnderlined)

            VStack(alignment: .leading, spacing: 8) {
                Text(model.localized(.note))
                    .font(.headline)
                TextEditor(text: $note)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 120)
                    .background(
                        Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(.separator)
                    }
            }

            HStack {
                if annotation != nil {
                    Button(model.localized(.deleteAnnotation), role: .destructive) {
                        onDelete()
                    }
                }

                Spacer()

                Button(model.localized(.save)) {
                    onSave(note, highlightColor, isUnderlined)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 580)
    }

    private func annotationColorButton(
        _ color: ParagraphHighlightColor?,
        label: String
    ) -> some View {
        Button {
            highlightColor = color
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(color?.color ?? Color.clear)
                        .frame(width: 28, height: 28)
                    Circle()
                        .strokeBorder(
                            highlightColor == color
                                ? Color.accentColor
                                : Color.secondary.opacity(0.35),
                            lineWidth: highlightColor == color ? 3 : 1
                        )
                        .frame(width: 32, height: 32)
                    if color == nil {
                        Image(systemName: "nosign")
                            .foregroundStyle(.secondary)
                    } else if highlightColor == color {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutGuideView: View {
    @EnvironmentObject private var model: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    private var shortcuts: [(keys: String, action: String)] {
        [
            ("fn + F9", model.localized(.nextChapter)),
            ("fn + F7", model.localized(.previousChapter)),
            (
                model.appLanguage == .simplifiedChinese
                    || model.appLanguage == .traditionalChinese
                    ? "空格"
                    : "Space",
                model.localized(.playPause)
            ),
            ("←", model.localized(.previousPage)),
            ("→", model.localized(.nextPage)),
            (
                model.localized(.twoFingerRight),
                model.localized(.previousPage)
            ),
            (
                model.localized(.twoFingerLeft),
                model.localized(.nextPage)
            ),
            ("Esc", model.localized(.exitApp))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text(model.localized(.shortcutTitle))
                    .font(.title2.bold())
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                ForEach(shortcuts, id: \.keys) { shortcut in
                    GridRow {
                        Text(shortcut.keys)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                .quaternary,
                                in: RoundedRectangle(cornerRadius: 7)
                            )
                            .gridColumnAlignment(.trailing)

                        Text(shortcut.action)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Label {
                Text(model.localized(.naturalScrollHint))
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(12)
            .background(
                Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10)
            )

            HStack {
                Spacer()
                Button(model.localized(.done)) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 420)
    }
}

private struct ParagraphView: View {
    let paragraph: ReadingParagraph
    let fragments: [ReadingPageFragment]
    let isCurrent: Bool
    let highlightedRange: NSRange?
    let annotations: [TextAnnotation]
    let fontSize: Double
    let language: AppLanguage
    let onSpeak: (Int) -> Void
    let onSelectionCommand: (
        TextSelectionCommand,
        NSRange,
        String
    ) -> Void

    @ViewBuilder
    var body: some View {
        if let displayRange {
            SelectableParagraphText(
                paragraphText: paragraph.text,
                displayRange: displayRange,
                annotations: annotations,
                spokenRange: highlightedRange,
                fontSize: fontSize,
                language: language,
                onSpeak: { characterOffset in
                    onSpeak(sentenceStart(containing: characterOffset))
                },
                onSelectionCommand: onSelectionCommand
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isCurrent
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear
                    )
            }
            .overlay(alignment: .leading) {
                if isCurrent {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 3)
                        .padding(.vertical, 9)
                }
            }
        }
    }

    private var displayRange: NSRange? {
        guard let first = fragments.first, let last = fragments.last else {
            return nil
        }
        return NSRange(
            location: first.range.location,
            length: NSMaxRange(last.range) - first.range.location
        )
    }

    private func sentenceStart(containing characterOffset: Int) -> Int {
        let sentences = SentenceSplitter.split(paragraph.text)
        if let sentence = sentences.first(where: {
            characterOffset >= $0.range.location
                && characterOffset < NSMaxRange($0.range)
        }) {
            return sentence.range.location
        }
        return max(min(characterOffset, (paragraph.text as NSString).length), 0)
    }
}

private extension ThemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private extension ParagraphHighlightColor {
    var color: Color {
        switch self {
        case .yellow:
            return Color(red: 0.91, green: 0.76, blue: 0.35)
        case .green:
            return Color(red: 0.47, green: 0.68, blue: 0.46)
        case .blue:
            return Color(red: 0.44, green: 0.65, blue: 0.75)
        case .pink:
            return Color(red: 0.86, green: 0.56, blue: 0.63)
        case .purple:
            return Color(red: 0.64, green: 0.53, blue: 0.76)
        }
    }
}

private extension VoiceQualityTier {
    var badgeColor: Color {
        switch self {
        case .standard:
            return .secondary
        case .enhanced:
            return .blue
        case .premium:
            return .purple
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
