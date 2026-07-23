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
            "声页提示",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            actions: {
                Button("好") { model.errorMessage = nil }
            },
            message: {
                Text(model.errorMessage ?? "发生未知错误。")
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
                    HStack(spacing: 16) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 66, height: 66)

                        Text("声页")
                            .font(.system(size: 32, weight: .semibold, design: .serif))

                        Spacer()

                        Button {
                            isShowingShortcutGuide = true
                        } label: {
                            Label("操作指南", systemImage: "keyboard")
                        }

                        Button {
                            isShowingVoiceCenter = true
                        } label: {
                            Label("音色中心", systemImage: "waveform.badge.plus")
                        }

                        Button {
                            isImporting = true
                        } label: {
                            Label("导入图书", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if model.isLoading {
                        ProgressView("正在整理章节和正文…")
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
                                        Text("继续上次阅读")
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
                    Text("我的图书")
                        .font(.headline)
                    Text(
                        model.libraryBooks.isEmpty
                            ? "打开书架并导入图书"
                            : "\(model.libraryBooks.count) 本图书"
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
                Label("观看历史", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()

                if !model.readingHistory.isEmpty {
                    if isSelectingHistory {
                        Button(
                            selectedHistoryIDs.count == model.readingHistory.count
                                ? "取消全选"
                                : "全选"
                        ) {
                            if selectedHistoryIDs.count == model.readingHistory.count {
                                selectedHistoryIDs.removeAll()
                            } else {
                                selectedHistoryIDs = Set(model.readingHistory.map(\.id))
                            }
                        }

                        Button("删除选中") {
                            model.removeHistory(ids: selectedHistoryIDs)
                            selectedHistoryIDs.removeAll()
                            isSelectingHistory = false
                        }
                        .disabled(selectedHistoryIDs.isEmpty)
                    }

                    Button(isSelectingHistory ? "完成" : "批量管理") {
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
                    title: "暂无观看历史",
                    detail: "开始阅读后会自动记录最近位置。"
                )
            } else {
                ForEach(ReadingHistoryPeriod.allCases) { period in
                    let entries = model.readingHistory.filter {
                        ReadingHistoryPeriod.period(for: $0.viewedAt) == period
                    }
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(period.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.14))
                                    .frame(height: 1)
                            }

                            ForEach(entries) { entry in
                                HomeHistoryRow(
                                    entry: entry,
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
                        Label("返回", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .help("返回主页")

                    Image(systemName: "books.vertical.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("我的图书")
                            .font(.title2.bold())
                        Text("\(model.libraryBooks.count) 本")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        isImporting = true
                    } label: {
                        Label("导入图书", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.ultraThinMaterial)

                Divider().opacity(0.5)

                if model.libraryBooks.isEmpty {
                    ContentUnavailableView {
                        Label("书架还是空的", systemImage: "books.vertical")
                    } description: {
                        Text("导入 EPUB 或 TXT 后，图书会保留在这台 Mac 上。")
                    } actions: {
                        Button("导入第一本图书") {
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
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("返回书架")

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
                label: Label("章节", systemImage: "list.bullet.rectangle")
            ) {
                ForEach(model.document.chapters) { chapter in
                    Text(chapter.title).tag(chapter.index)
                }
            }
            .pickerStyle(.menu)
            .frame(width: min(isFullScreen ? 380 : 280, 380))
            .help("选择章节并跳转到该章开头")
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
                Text("正在整理章节和自然段…")
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
                "没有可显示的文字",
                systemImage: "text.book.closed",
                description: Text("请返回并打开一本 EPUB 或 TXT 书籍。")
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
            .help("上一章（⇧⌘←）")

            Button {
                model.showPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24)
            }
            .disabled(model.currentPage == 0)
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .help("上一页（⌘←）")

            Button {
                model.startOrResume()
            } label: {
                Image(systemName: model.isSpeaking ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 34, height: 28)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.space, modifiers: [])
            .help(model.isSpeaking ? "暂停朗读（空格）" : "从当前页开始朗读（空格）")

            if !model.isFollowingSpeech && (model.isSpeaking || model.isPaused) {
                Button {
                    model.resumeFollowingSpeech()
                } label: {
                    Label("返回朗读位置", systemImage: "location.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("回到当前正在朗读的页面并恢复自动翻页")
            }

            Spacer(minLength: 12)

            if isFullScreen {
                HStack(spacing: 24) {
                    Label("剩余电量 \(model.batteryText)", systemImage: "battery.75percent")
                    Label(model.clockText, systemImage: "clock")
                    Label(
                        "进度 \(model.readingProgressPercentage)%",
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
            .help("下一页（⌘→）")

            Button {
                model.selectNextChapter()
            } label: {
                Image(systemName: "forward.end.fill")
                    .frame(width: 24)
            }
            .disabled(model.selectedChapterIndex + 1 >= model.document.chapters.count)
            .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            .help("下一章（⇧⌘→）")
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
                    Label("阅读设置", systemImage: "slider.horizontal.3")
                        .font(.headline)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Label("朗读声音", systemImage: "waveform")
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
                                            ? "个人声音"
                                            : "\(model.currentVoiceQuality.label)品质"
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
                        title: "语速",
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
                        title: "跟随朗读自动翻页",
                        icon: "rectangle.portrait.on.rectangle.portrait",
                        detail: model.autoFollowSpeech
                            ? "朗读进入下一页时自动跟随"
                            : "朗读时保持当前浏览页面",
                        isOn: Binding(
                            get: { model.autoFollowSpeech },
                            set: { model.updateAutoFollowSpeech($0) }
                        )
                    )

                    settingPicker(
                        title: "停止条件",
                        icon: "moon.zzz",
                        selection: Binding(
                            get: { model.timerOption },
                            set: { model.setSleepTimer($0) }
                        )
                    ) {
                        ForEach(SleepTimerOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    settingPicker(
                        title: "显示模式",
                        icon: "circle.lefthalf.filled",
                        selection: Binding(
                            get: { model.themePreference },
                            set: { model.updateTheme($0) }
                        )
                    ) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }

                    settingToggle(
                        title: "护眼模式",
                        icon: "leaf.fill",
                        detail: "低饱和暖绿阅读背景",
                        isOn: Binding(
                            get: { model.eyeCareMode },
                            set: { model.updateEyeCareMode($0) }
                        )
                    )

                    settingSlider(
                        title: "字体大小",
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
                        title: "页面亮度",
                        icon: "sun.max.fill",
                        valueText: "\(Int(model.pageBrightness * 100))%",
                        value: Binding(
                            get: { model.pageBrightness },
                            set: { model.updateBrightness($0) }
                        ),
                        range: 0.35...1,
                        step: 0.05
                    )

                    Text("拖动选择文字后右键，可高亮、批注、下划线、翻译或拷贝")
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
            .help(model.controlsExpanded ? "收起阅读设置" : "展开阅读设置")
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
                model.errorMessage = "系统翻译功能需要 macOS 14.4 或更高版本。"
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
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Button(action: onOpen) {
                    BookshelfCover(
                        book: book,
                        image: coverImage
                    )
                }
                .buttonStyle(.plain)
                .disabled(!book.isAvailable)

                Menu {
                    Button(
                        "从我的图书移除",
                        role: .destructive,
                        action: onRemove
                    )
                    Text("不会删除原始文件")
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
                    Text("进度 \(history.progressPercentage)%")
                }
                if !book.isAvailable {
                    Text("· 原文件不可用")
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
        .help(book.isAvailable ? "打开《\(book.title)》" : "原文件不可用")
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
                .help("删除这条观看历史，不会移除图书")
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
                    Label("音色中心", systemImage: "waveform.circle.fill")
                        .font(.title2.bold())
                    Text("集中管理已安装音色、系统音色下载和个人声音。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
            }

            HStack(spacing: 14) {
                voiceCenterCard(
                    title: "已安装音色",
                    detail: "当前：\(model.currentVoiceName)\n可试听、搜索和收藏本机音色。",
                    icon: "waveform",
                    buttonTitle: "选择朗读音色",
                    action: onOpenVoiceLibrary
                )

                voiceCenterCard(
                    title: "增强／高级音色",
                    detail: "由 macOS 下载并保存在本机，可获得更自然的朗读效果。",
                    icon: "arrow.down.circle",
                    buttonTitle: "打开系统音色下载",
                    action: model.openVoiceManagement
                )

                voiceCenterCard(
                    title: "个人声音",
                    detail: "状态：\(model.personalVoiceAccessState.label)\n已发现 \(model.personalVoiceCount) 个个人声音。",
                    icon: "person.wave.2",
                    buttonTitle: "录制与授权说明",
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
            return voice.displayName.localizedCaseInsensitiveContains(searchText)
                || voice.gender.label.localizedCaseInsensitiveContains(searchText)
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
            return lhs.displayName.localizedStandardCompare(rhs.displayName)
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
                    Text("本地音色库")
                        .font(.title2.bold())
                    Text("选择已下载到这台 Mac 的系统音色，朗读过程不会上传书籍内容。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Divider()

            List(displayedVoices) { voice in
                VoiceLibraryRow(
                    voice: voice,
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
            .searchable(text: $searchText, prompt: "搜索音色、语言或性别")
            .overlay {
                if displayedVoices.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }

            Divider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("想要更自然的增强或高级音色？")
                        .font(.callout.weight(.medium))
                    Text("在系统设置中下载音色，返回声页后点“刷新”即可使用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.openVoiceManagement()
                } label: {
                    Label("打开系统音色管理", systemImage: "arrow.up.forward.app")
                }

                Button {
                    model.refreshVoices()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
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
                        Text("\(localizedLanguage) · \(voice.gender.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(voice.isPersonal ? "个人声音" : voice.quality.label)
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
            .help("试听音色")

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.orange : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isFavorite ? "取消收藏" : "收藏音色")
        }
        .padding(.vertical, 4)
    }

    private var localizedLanguage: String {
        Locale(identifier: "zh-Hans")
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
                    Text("录制并使用个人声音")
                        .font(.title2.bold())
                    Text("录音和声音生成由 macOS 在本机完成，声页不会读取原始录音。")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("完成") {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                personalVoiceStep(
                    number: 1,
                    title: "在系统设置中创建个人声音",
                    detail: "按照系统提示朗读句子，等待 Mac 在本机完成声音生成。"
                )
                personalVoiceStep(
                    number: 2,
                    title: "允许声页使用个人声音",
                    detail: "系统会显示一次授权提示；授权后个人声音才会出现在音色库。"
                )
                personalVoiceStep(
                    number: 3,
                    title: "返回声页刷新并选择",
                    detail: "个人声音会带有“个人声音”标记，可像其他音色一样试听和使用。"
                )
            }
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Label(
                    "当前状态：\(model.personalVoiceAccessState.label)",
                    systemImage: personalVoiceStatusIcon
                )
                .foregroundStyle(personalVoiceStatusColor)

                Spacer()

                if model.personalVoiceCount > 0 {
                    Text("已发现 \(model.personalVoiceCount) 个个人声音")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("要求：Apple 芯片 Mac、受支持的系统语言及 macOS 14 或更高版本。Apple 规定个人声音仅限本人创建，并用于个人非商业用途。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if model.personalVoiceAccessState != .authorized {
                Label(
                    "更新版本后若一直显示“尚未授权”，请打开个人声音设置，在应用列表中选中并移除旧的“声页”，再返回此处重新允许。",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    model.openPersonalVoiceSettings()
                } label: {
                    Label("打开个人声音设置", systemImage: "arrow.up.forward.app")
                }

                Spacer()

                Button {
                    model.requestPersonalVoiceAccess()
                } label: {
                    Label(
                        model.personalVoiceAccessState == .authorized
                            ? "刷新个人声音"
                            : "允许声页使用",
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
                    annotation == nil ? "添加文字批注" : "编辑文字批注",
                    systemImage: "highlighter"
                )
                .font(.title2.bold())
                Spacer()
                Button("取消") {
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
                Text("高亮颜色")
                    .font(.headline)

                HStack(spacing: 12) {
                    annotationColorButton(nil, label: "无")
                    ForEach(ParagraphHighlightColor.allCases) { color in
                        annotationColorButton(color, label: color.label)
                    }
                }
            }

            Toggle("为所选文字添加下划线", isOn: $isUnderlined)

            VStack(alignment: .leading, spacing: 8) {
                Text("注释")
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
                    Button("删除批注", role: .destructive) {
                        onDelete()
                    }
                }

                Spacer()

                Button("保存") {
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
    @Environment(\.dismiss) private var dismiss

    private let shortcuts: [(keys: String, action: String)] = [
        ("fn + F9", "下一章"),
        ("fn + F7", "上一章"),
        ("空格", "播放 / 暂停"),
        ("←", "上一页"),
        ("→", "下一页"),
        ("两指右滑", "上一页"),
        ("两指左滑", "下一页"),
        ("Esc", "退出应用")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("快捷操作指南")
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
                Text("若鼠标设置中开启了“自然滚动”，触控板双指翻页方向可能与上方描述相反。")
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
                Button("完成") {
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
