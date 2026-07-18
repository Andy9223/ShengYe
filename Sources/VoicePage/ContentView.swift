import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: ReaderViewModel
    @State private var isImporting = false
    @State private var isFullScreen = false
    @State private var isShowingShortcutGuide = false

    var body: some View {
        Group {
            switch model.screen {
            case .library:
                libraryView
            case .reader:
                readerView
            }
        }
        .preferredColorScheme(model.themePreference.colorScheme)
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
            "无法打开书籍",
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
        .onReceive(NotificationCenter.default.publisher(for: .openBook)) { _ in
            model.returnToLibrary()
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
    }

    private var libraryView: some View {
        ZStack {
            readerBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 84, height: 84)

                VStack(spacing: 8) {
                    Text("声页")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                    Text("选择一本 EPUB 或 TXT，开始听读")
                        .foregroundStyle(.secondary)
                }

                if model.isLoading {
                    ProgressView("正在整理章节和正文…")
                        .controlSize(.large)
                        .frame(height: 58)
                } else {
                    VStack(spacing: 12) {
                        Button {
                            isImporting = true
                        } label: {
                            Label("打开书籍", systemImage: "books.vertical.fill")
                                .frame(width: 190)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        if model.hasOpenBook {
                            Button {
                                model.continueReading()
                            } label: {
                                Label(
                                    "继续阅读《\(model.document.title)》",
                                    systemImage: "bookmark.fill"
                                )
                                .lineLimit(1)
                                .frame(maxWidth: 300)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        Button {
                            isShowingShortcutGuide = true
                        } label: {
                            Label("快捷操作指南", systemImage: "keyboard")
                                .frame(width: 190)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(48)
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
                                    fontSize: model.fontSize
                                ) { sentenceOffset in
                                    model.startSpeaking(
                                        at: paragraph.index,
                                        characterOffset: sentenceOffset
                                    )
                                }
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

                    settingPicker(
                        title: "朗读声音",
                        icon: "waveform",
                        selection: Binding(
                            get: { model.selectedVoiceID },
                            set: { model.updateVoice($0) }
                        )
                    ) {
                        ForEach(model.voices) { voice in
                            Text(voice.displayName).tag(voice.id)
                        }
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

                    Text("单击正文中的任意句子即可从该句开始朗读")
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

    private var readerBackground: Color {
        Color(nsColor: .textBackgroundColor)
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

            Text("触控板横向滑动一次只翻一页，纵向滑动不会触发翻页。")
                .font(.footnote)
                .foregroundStyle(.tertiary)

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
    let fontSize: Double
    let action: (Int) -> Void

    var body: some View {
        SentenceFlowLayout(spacing: 1, lineSpacing: fontSize * 0.45) {
            ForEach(fragments) { fragment in
                Button {
                    action(fragment.sentenceStartOffset)
                } label: {
                    highlightedText(for: fragment)
                        .font(.system(size: fontSize, weight: .regular, design: .serif))
                        .lineSpacing(fontSize * 0.42)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .help("从这句话开始朗读")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : .clear)
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

    private func highlightedText(for fragment: ReadingPageFragment) -> Text {
        let nsParagraph = paragraph.text as NSString
        let fragmentText = nsParagraph.substring(with: fragment.range)

        guard let highlightedRange else {
            return Text(fragmentText)
        }
        let intersection = NSIntersectionRange(fragment.range, highlightedRange)
        guard intersection.location != NSNotFound, intersection.length > 0 else {
            return Text(fragmentText)
        }

        let nsFragment = fragmentText as NSString
        let relativeLocation = intersection.location - fragment.range.location
        let before = nsFragment.substring(
            with: NSRange(location: 0, length: relativeLocation)
        )
        let highlighted = nsFragment.substring(
            with: NSRange(location: relativeLocation, length: intersection.length)
        )
        let afterLocation = relativeLocation + intersection.length
        let after = nsFragment.substring(
            from: min(afterLocation, nsFragment.length)
        )

        return Text(before)
            + Text(highlighted).foregroundColor(.accentColor).bold()
            + Text(after)
    }
}

private struct SentenceFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 700
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = fittedSize(for: subview, maxWidth: maxWidth)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = fittedSize(for: subview, maxWidth: bounds.width)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func fittedSize(
        for subview: LayoutSubview,
        maxWidth: CGFloat
    ) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        if ideal.width <= maxWidth {
            return ideal
        }
        return subview.sizeThatFits(
            ProposedViewSize(width: maxWidth, height: nil)
        )
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

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
