import AppKit
import SwiftUI

enum TextSelectionCommand {
    case highlight(ParagraphHighlightColor?)
    case addNote
    case clearNote
    case toggleUnderline
    case translate
}

struct SelectableParagraphText: NSViewRepresentable {
    let paragraphText: String
    let displayRange: NSRange
    let annotations: [TextAnnotation]
    let spokenRange: NSRange?
    let fontSize: Double
    let language: AppLanguage
    let onSpeak: (Int) -> Void
    let onSelectionCommand: (TextSelectionCommand, NSRange, String) -> Void

    func makeNSView(context: Context) -> VoicePageTextView {
        VoicePageTextView()
    }

    func updateNSView(_ textView: VoicePageTextView, context: Context) {
        textView.updateContent(
            paragraphText: paragraphText,
            displayRange: displayRange,
            annotations: annotations,
            spokenRange: spokenRange,
            fontSize: fontSize,
            language: language,
            onSpeak: onSpeak,
            onSelectionCommand: onSelectionCommand
        )
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: VoicePageTextView,
        context: Context
    ) -> CGSize? {
        let width = max(proposal.width ?? 620, 120)
        return CGSize(
            width: width,
            height: nsView.requiredHeight(for: width)
        )
    }
}

final class VoicePageTextView: NSTextView {
    private var paragraphText = ""
    private var paragraphDisplayRange = NSRange(location: 0, length: 0)
    private var paragraphAnnotations: [TextAnnotation] = []
    private var speechAction: ((Int) -> Void)?
    private var selectionAction: (
        (TextSelectionCommand, NSRange, String) -> Void
    )?
    private var currentFontSize: Double = 20
    private var currentLanguage: AppLanguage = .simplifiedChinese

    init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: 0,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        super.init(frame: .zero, textContainer: textContainer)

        isEditable = false
        isSelectable = true
        drawsBackground = false
        allowsUndo = false
        isRichText = false
        importsGraphics = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = true
        isHorizontallyResizable = false
        isVerticallyResizable = true
        autoresizingMask = [.width]
        focusRingType = .none
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateContent(
        paragraphText: String,
        displayRange: NSRange,
        annotations: [TextAnnotation],
        spokenRange: NSRange?,
        fontSize: Double,
        language: AppLanguage,
        onSpeak: @escaping (Int) -> Void,
        onSelectionCommand: @escaping (
            TextSelectionCommand,
            NSRange,
            String
        ) -> Void
    ) {
        let nsParagraph = paragraphText as NSString
        guard displayRange.location >= 0,
              displayRange.length > 0,
              NSMaxRange(displayRange) <= nsParagraph.length else {
            textStorage?.setAttributedString(NSAttributedString())
            return
        }

        self.paragraphText = paragraphText
        paragraphDisplayRange = displayRange
        paragraphAnnotations = annotations
        speechAction = onSpeak
        selectionAction = onSelectionCommand
        currentFontSize = fontSize
        currentLanguage = language

        let visibleText = nsParagraph.substring(with: displayRange)
        let renderedFontSize = CGFloat(
            min(max(fontSize.rounded(), 15), 34)
        )
        let baseFont = NSFont(
            name: "New York",
            size: renderedFontSize
        ) ?? NSFont.systemFont(ofSize: renderedFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = renderedFontSize * 0.42
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributedText = NSMutableAttributedString(
            string: visibleText,
            attributes: [
                .font: baseFont,
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        for annotation in annotations {
            let intersection = NSIntersectionRange(
                annotation.range.nsRange,
                displayRange
            )
            guard intersection.location != NSNotFound,
                  intersection.length > 0 else {
                continue
            }
            let localRange = NSRange(
                location: intersection.location - displayRange.location,
                length: intersection.length
            )
            if let color = annotation.highlightColor {
                attributedText.addAttribute(
                    .backgroundColor,
                    value: color.nsColor.withAlphaComponent(0.32),
                    range: localRange
                )
            }
            if annotation.isUnderlined {
                attributedText.addAttributes(
                    [
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .underlineColor: NSColor.secondaryLabelColor
                    ],
                    range: localRange
                )
            }
        }

        if let spokenRange {
            let intersection = NSIntersectionRange(spokenRange, displayRange)
            if intersection.location != NSNotFound, intersection.length > 0 {
                let localRange = NSRange(
                    location: intersection.location - displayRange.location,
                    length: intersection.length
                )
                attributedText.addAttributes(
                    [
                        .foregroundColor: NSColor.controlAccentColor,
                        .font: NSFont.boldSystemFont(
                            ofSize: renderedFontSize
                        )
                    ],
                    range: localRange
                )
            }
        }

        let previousSelection = selectedRange()
        textStorage?.beginEditing()
        textStorage?.setAttributedString(attributedText)
        textStorage?.endEditing()
        font = baseFont
        let safeSelection = NSRange(
            location: min(previousSelection.location, attributedText.length),
            length: min(
                previousSelection.length,
                max(attributedText.length - previousSelection.location, 0)
            )
        )
        setSelectedRange(safeSelection)
        layoutManager?.invalidateLayout(
            forCharacterRange: NSRange(
                location: 0,
                length: attributedText.length
            ),
            actualCharacterRange: nil
        )
        if let textContainer {
            layoutManager?.ensureLayout(for: textContainer)
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
        needsDisplay = true
    }

    func requiredHeight(for width: CGFloat) -> CGFloat {
        guard let textContainer, let layoutManager else {
            return currentFontSize * 1.8
        }
        frame.size.width = width
        textContainer.containerSize = NSSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
        layoutManager.ensureLayout(for: textContainer)
        let height = layoutManager.usedRect(for: textContainer).height
        return max(ceil(height) + 2, currentFontSize * 1.35)
    }

    override func mouseDown(with event: NSEvent) {
        let clickedCharacterIndex = event.buttonNumber == 0
            ? characterIndex(at: event)
            : nil

        // NSTextView tracks the complete selection gesture inside mouseDown.
        // Inspecting the selection after super returns lets a simple click
        // start speech without turning a drag-to-select gesture into playback.
        super.mouseDown(with: event)

        guard event.buttonNumber == 0,
              event.clickCount == 1,
              selectedRange().length == 0,
              let clickedCharacterIndex else {
            return
        }
        speechAction?(
            paragraphDisplayRange.location + clickedCharacterIndex
        )
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let localSelection = selectedRange()
        guard localSelection.length > 0,
              NSMaxRange(localSelection) <= (string as NSString).length else {
            return nil
        }

        let menu = NSMenu()
        menu.allowsContextMenuPlugIns = false
        if #available(macOS 15.2, *) {
            menu.automaticallyInsertsWritingToolsItems = false
        }

        let highlightItem = NSMenuItem(
            title: localized(.contextHighlight),
            action: nil,
            keyEquivalent: ""
        )
        let colorsMenu = NSMenu(title: localized(.contextHighlight))
        for color in ParagraphHighlightColor.allCases {
            let item = NSMenuItem(
                title: color.localizedLabel(language: currentLanguage),
                action: #selector(applyHighlight(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = color.rawValue
            item.image = color.menuSwatch
            colorsMenu.addItem(item)
        }
        colorsMenu.addItem(.separator())
        let removeHighlight = NSMenuItem(
            title: localized(.clearHighlight),
            action: #selector(removeHighlight(_:)),
            keyEquivalent: ""
        )
        removeHighlight.target = self
        colorsMenu.addItem(removeHighlight)
        highlightItem.submenu = colorsMenu
        menu.addItem(highlightItem)

        let noteItem = NSMenuItem(
            title: selectionHasNote
                ? localized(.editNote)
                : localized(.addNote),
            action: #selector(addNote(_:)),
            keyEquivalent: ""
        )
        noteItem.target = self
        menu.addItem(noteItem)

        if selectionHasNote {
            let clearNoteItem = NSMenuItem(
                title: localized(.clearNote),
                action: #selector(clearNote(_:)),
                keyEquivalent: ""
            )
            clearNoteItem.target = self
            menu.addItem(clearNoteItem)
        }

        let underlineItem = NSMenuItem(
            title: selectionHasUnderline
                ? localized(.removeUnderline)
                : localized(.underline),
            action: #selector(toggleUnderline(_:)),
            keyEquivalent: ""
        )
        underlineItem.target = self
        menu.addItem(underlineItem)

        menu.addItem(.separator())

        let translateItem = NSMenuItem(
            title: localized(.translate),
            action: #selector(translateSelection(_:)),
            keyEquivalent: ""
        )
        translateItem.target = self
        menu.addItem(translateItem)

        let copyItem = NSMenuItem(
            title: localized(.copy),
            action: #selector(copy(_:)),
            keyEquivalent: "c"
        )
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        menu.addItem(copyItem)

        return menu
    }

    private func localized(_ key: AppText) -> String {
        AppLocalization.text(key, language: currentLanguage)
    }

    @objc private func applyHighlight(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let color = ParagraphHighlightColor(rawValue: rawValue) else {
            return
        }
        performSelectionCommand(.highlight(color))
    }

    @objc private func removeHighlight(_ sender: NSMenuItem) {
        performSelectionCommand(.highlight(nil))
    }

    @objc private func addNote(_ sender: NSMenuItem) {
        performSelectionCommand(.addNote)
    }

    @objc private func clearNote(_ sender: NSMenuItem) {
        performSelectionCommand(.clearNote)
    }

    @objc private func toggleUnderline(_ sender: NSMenuItem) {
        performSelectionCommand(.toggleUnderline)
    }

    @objc private func translateSelection(_ sender: NSMenuItem) {
        performSelectionCommand(.translate)
    }

    private func performSelectionCommand(_ command: TextSelectionCommand) {
        let localRange = selectedRange()
        guard localRange.length > 0,
              NSMaxRange(localRange) <= (string as NSString).length else {
            return
        }
        let paragraphRange = NSRange(
            location: paragraphDisplayRange.location + localRange.location,
            length: localRange.length
        )
        let selectedText = (string as NSString).substring(with: localRange)
        selectionAction?(command, paragraphRange, selectedText)
    }

    private var selectionHasUnderline: Bool {
        selectionAnnotation?.isUnderlined ?? false
    }

    private var selectionHasNote: Bool {
        guard let annotation = selectionAnnotation else { return false }
        return !annotation.note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var selectionAnnotation: TextAnnotation? {
        let localRange = selectedRange()
        let paragraphRange = NSRange(
            location: paragraphDisplayRange.location + localRange.location,
            length: localRange.length
        )
        return paragraphAnnotations.first {
            $0.range.nsRange == paragraphRange
        }
    }

    private func characterIndex(at event: NSEvent) -> Int? {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.insetBy(dx: -4, dy: -4).contains(point) else {
            return nil
        }
        let index = characterIndexForInsertion(at: point)
        let textLength = (string as NSString).length
        guard index < textLength else { return nil }
        return index
    }
}

private extension ParagraphHighlightColor {
    var nsColor: NSColor {
        switch self {
        case .yellow:
            return NSColor(
                calibratedRed: 0.91,
                green: 0.76,
                blue: 0.35,
                alpha: 1
            )
        case .green:
            return NSColor(
                calibratedRed: 0.47,
                green: 0.68,
                blue: 0.46,
                alpha: 1
            )
        case .blue:
            return NSColor(
                calibratedRed: 0.44,
                green: 0.65,
                blue: 0.75,
                alpha: 1
            )
        case .pink:
            return NSColor(
                calibratedRed: 0.86,
                green: 0.56,
                blue: 0.63,
                alpha: 1
            )
        case .purple:
            return NSColor(
                calibratedRed: 0.64,
                green: 0.53,
                blue: 0.76,
                alpha: 1
            )
        }
    }

    var menuSwatch: NSImage {
        let size = NSSize(width: 13, height: 13)
        let image = NSImage(size: size)
        image.lockFocus()
        nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
