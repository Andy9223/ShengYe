import Foundation
import CoreFoundation

enum DocumentLoaderError: LocalizedError {
    case unsupportedType
    case unreadableText
    case invalidEPUB
    case emptyDocument
    case unzipFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "暂不支持这种文件格式。请选择 EPUB 或 TXT 文件。"
        case .unreadableText:
            return "无法识别文本编码。建议将文件保存为 UTF-8 后重试。"
        case .invalidEPUB:
            return "EPUB 文件结构不完整，无法找到书籍正文。"
        case .emptyDocument:
            return "文件中没有找到可朗读的文字。"
        case .unzipFailed(let detail):
            return "无法解压 EPUB 文件。\(detail)"
        }
    }
}

enum DocumentLoader {
    static func load(from url: URL) throws -> ReadingDocument {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        switch url.pathExtension.lowercased() {
        case "txt":
            return try loadText(from: url)
        case "epub":
            return try loadEPUB(from: url)
        default:
            throw DocumentLoaderError.unsupportedType
        }
    }

    private static func loadText(from url: URL) throws -> ReadingDocument {
        let data = try Data(contentsOf: url)
        guard let text = decodeText(data) else {
            throw DocumentLoaderError.unreadableText
        }

        let paragraphs = makeParagraphs(from: text)
        guard !paragraphs.isEmpty else {
            throw DocumentLoaderError.emptyDocument
        }
        let chapters = makeChapters(from: paragraphs)

        return ReadingDocument(
            title: url.deletingPathExtension().lastPathComponent,
            sourceURL: url,
            paragraphs: paragraphs,
            chapters: chapters,
            sections: makeSections(from: paragraphs, chapters: chapters)
        )
    }

    private static func loadEPUB(from url: URL) throws -> ReadingDocument {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("VoicePage-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-qq", "-o", url.path, "-d", tempDirectory.path]

        let errorPipe = Pipe()
        unzip.standardError = errorPipe
        try unzip.run()
        unzip.waitUntilExit()

        guard unzip.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw DocumentLoaderError.unzipFailed(detail)
        }

        let containerURL = tempDirectory
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")
        guard let containerData = try? Data(contentsOf: containerURL) else {
            throw DocumentLoaderError.invalidEPUB
        }

        let containerParser = ContainerXMLParser()
        guard let opfPath = containerParser.parse(data: containerData) else {
            throw DocumentLoaderError.invalidEPUB
        }

        let opfURL = tempDirectory.appendingPathComponent(opfPath)
        let opfData = try Data(contentsOf: opfURL)
        let packageParser = PackageXMLParser()
        let package = packageParser.parse(data: opfData)
        let baseURL = opfURL.deletingLastPathComponent()
        let navigationTitles = loadNavigationTitles(
            package: package,
            baseURL: baseURL
        )

        var allParagraphTexts: [String] = []
        var chapters: [ReadingChapter] = []
        var sections: [ReadingSection] = []
        for itemID in package.spine {
            guard let manifestItem = package.manifest[itemID] else { continue }
            let href = manifestItem.href.removingPercentEncoding ?? manifestItem.href
            let itemURL = baseURL
                .appendingPathComponent(href)
                .standardizedFileURL
            guard let htmlData = try? Data(contentsOf: itemURL),
                  let html = decodeText(htmlData) else {
                continue
            }

            appendEPUBContent(
                html,
                chapterTitleOverride: navigationTitles[itemURL.path],
                paragraphTexts: &allParagraphTexts,
                chapters: &chapters,
                sections: &sections
            )
        }

        if allParagraphTexts.isEmpty {
            let fallbackFiles = recursiveHTMLFiles(in: tempDirectory)
            for itemURL in fallbackFiles {
                guard let htmlData = try? Data(contentsOf: itemURL),
                      let html = decodeText(htmlData) else {
                    continue
                }

                appendEPUBContent(
                    html,
                    chapterTitleOverride: navigationTitles[itemURL.standardizedFileURL.path],
                    paragraphTexts: &allParagraphTexts,
                    chapters: &chapters,
                    sections: &sections
                )
            }
        }

        let cleanedTexts = allParagraphTexts
            .map(cleanParagraph)
            .filter { !$0.isEmpty }
        guard !cleanedTexts.isEmpty else {
            throw DocumentLoaderError.emptyDocument
        }

        let title = package.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (title?.isEmpty == false)
            ? title!
            : url.deletingPathExtension().lastPathComponent

        let paragraphs = cleanedTexts.enumerated().map {
            ReadingParagraph(index: $0.offset, text: $0.element)
        }
        let resolvedChapters = chapters.isEmpty
            ? makeChapters(from: paragraphs)
            : chapters
        let resolvedSections = sections.isEmpty
            ? makeSections(from: paragraphs, chapters: resolvedChapters)
            : sections

        return ReadingDocument(
            title: resolvedTitle,
            sourceURL: url,
            paragraphs: paragraphs,
            chapters: resolvedChapters,
            sections: resolvedSections
        )
    }

    static func makeParagraphs(from text: String) -> [ReadingParagraph] {
        splitParagraphText(text).enumerated().map {
            ReadingParagraph(index: $0.offset, text: $0.element)
        }
    }

    static func makeChapters(from paragraphs: [ReadingParagraph]) -> [ReadingChapter] {
        guard !paragraphs.isEmpty else { return [] }

        let detectedHeadings = paragraphs.filter {
            isLikelyChapterHeading($0.text)
        }
        guard !detectedHeadings.isEmpty else {
            return [
                ReadingChapter(index: 0, title: "全文", startParagraphIndex: 0)
            ]
        }

        var starts: [(title: String, paragraphIndex: Int)] = []
        if let firstHeading = detectedHeadings.first, firstHeading.index > 0 {
            starts.append(("开篇", 0))
        }
        starts.append(contentsOf: detectedHeadings.map { ($0.text, $0.index) })

        return starts.enumerated().map {
            ReadingChapter(
                index: $0.offset,
                title: $0.element.title,
                startParagraphIndex: $0.element.paragraphIndex
            )
        }
    }

    static func makeSections(
        from paragraphs: [ReadingParagraph],
        chapters: [ReadingChapter]
    ) -> [ReadingSection] {
        guard !paragraphs.isEmpty, !chapters.isEmpty else { return [] }

        var sections: [ReadingSection] = []
        for (chapterOffset, chapter) in chapters.enumerated() {
            let chapterEnd = chapterOffset + 1 < chapters.count
                ? chapters[chapterOffset + 1].startParagraphIndex
                : paragraphs.count

            sections.append(
                ReadingSection(
                    index: sections.count,
                    title: chapter.title,
                    startParagraphIndex: chapter.startParagraphIndex,
                    chapterIndex: chapter.index
                )
            )

            let searchStart = min(chapter.startParagraphIndex + 1, chapterEnd)
            guard searchStart < chapterEnd else { continue }
            for paragraphIndex in searchStart..<chapterEnd {
                let paragraph = paragraphs[paragraphIndex]
                guard isLikelySectionHeading(paragraph.text) else { continue }
                sections.append(
                    ReadingSection(
                        index: sections.count,
                        title: paragraph.text,
                        startParagraphIndex: paragraph.index,
                        chapterIndex: chapter.index
                    )
                )
            }
        }
        return sections
    }

    private static func loadNavigationTitles(
        package: PackageXMLParser.Package,
        baseURL: URL
    ) -> [String: String] {
        var titles: [String: String] = [:]

        let navigationItems = package.manifest.values.filter {
            $0.properties.lowercased()
                .split(whereSeparator: \.isWhitespace)
                .contains("nav")
        }
        for item in navigationItems {
            let href = item.href.removingPercentEncoding ?? item.href
            let navigationURL = baseURL
                .appendingPathComponent(href)
                .standardizedFileURL
            guard let data = try? Data(contentsOf: navigationURL),
                  let html = decodeText(data) else {
                continue
            }
            addNavigationEntries(
                extractHTMLNavigationEntries(html),
                relativeTo: navigationURL,
                titles: &titles
            )
        }

        let ncxItems = package.manifest.filter { id, item in
            id == package.tocID
                || item.mediaType.lowercased() == "application/x-dtbncx+xml"
        }.map(\.value)

        for item in ncxItems {
            let href = item.href.removingPercentEncoding ?? item.href
            let ncxURL = baseURL
                .appendingPathComponent(href)
                .standardizedFileURL
            guard let data = try? Data(contentsOf: ncxURL) else { continue }
            let entries = NavigationXMLParser().parse(data: data)
            addNavigationEntries(
                entries,
                relativeTo: ncxURL,
                titles: &titles
            )
        }
        return titles
    }

    private static func addNavigationEntries(
        _ entries: [(href: String, title: String)],
        relativeTo navigationURL: URL,
        titles: inout [String: String]
    ) {
        let directory = navigationURL.deletingLastPathComponent()
        for entry in entries {
            let decodedHref = entry.href.removingPercentEncoding ?? entry.href
            let pathPart = decodedHref
                .split(separator: "#", maxSplits: 1)
                .first
                .map(String.init) ?? decodedHref
            let cleanPath = pathPart
                .split(separator: "?", maxSplits: 1)
                .first
                .map(String.init) ?? pathPart
            guard !cleanPath.isEmpty else { continue }

            let targetURL = URL(
                fileURLWithPath: cleanPath,
                relativeTo: directory
            ).standardizedFileURL
            let title = cleanParagraph(entry.title)
            guard !title.isEmpty, titles[targetURL.path] == nil else { continue }
            titles[targetURL.path] = title
        }
    }

    private static func extractHTMLNavigationEntries(
        _ html: String
    ) -> [(href: String, title: String)] {
        let anchorPattern = #"(?is)<a\b([^>]*)>(.*?)</a>"#
        let hrefPattern = #"(?i)\bhref\s*=\s*["']([^"']+)["']"#
        guard let anchorRegex = try? NSRegularExpression(pattern: anchorPattern),
              let hrefRegex = try? NSRegularExpression(pattern: hrefPattern) else {
            return []
        }

        return anchorRegex.matches(
            in: html,
            range: NSRange(html.startIndex..., in: html)
        ).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: html),
                  let labelRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            let attributes = String(html[attributesRange])
            guard let hrefMatch = hrefRegex.firstMatch(
                in: attributes,
                range: NSRange(attributes.startIndex..., in: attributes)
            ),
                  let hrefRange = Range(hrefMatch.range(at: 1), in: attributes) else {
                return nil
            }

            let label = decodeHTMLEntities(
                String(html[labelRange]).replacingOccurrences(
                    of: "<[^>]+>",
                    with: "",
                    options: .regularExpression
                )
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return (String(attributes[hrefRange]), label)
        }
    }

    private static func appendEPUBContent(
        _ html: String,
        chapterTitleOverride: String?,
        paragraphTexts: inout [String],
        chapters: inout [ReadingChapter],
        sections: inout [ReadingSection]
    ) {
        let chapterParagraphs = splitParagraphText(htmlToPlainText(html))
        guard !chapterParagraphs.isEmpty else { return }

        let chapterIndex = chapters.count
        let chapterStart = paragraphTexts.count
        let chapterTitle = chapterTitleOverride
            ?? extractHTMLChapterTitle(html)
            ?? inferredChapterTitle(
                from: chapterParagraphs,
                fallbackNumber: chapterIndex + 1
            )
        chapters.append(
            ReadingChapter(
                index: chapterIndex,
                title: chapterTitle,
                startParagraphIndex: chapterStart
            )
        )

        var localSectionStarts: [Int: String] = [0: chapterTitle]
        var headingSearchStart = 0
        for title in extractHTMLSectionTitles(html) {
            guard headingSearchStart < chapterParagraphs.count,
                  let localIndex = chapterParagraphs.indices
                    .dropFirst(headingSearchStart)
                    .first(where: {
                        cleanParagraph(chapterParagraphs[$0]) == cleanParagraph(title)
                    }) else {
                continue
            }
            localSectionStarts[localIndex] = title
            headingSearchStart = localIndex + 1
        }

        for (localIndex, text) in chapterParagraphs.enumerated()
        where isLikelySectionHeading(text) {
            localSectionStarts[localIndex] = text
        }

        for (localIndex, title) in localSectionStarts.sorted(by: { $0.key < $1.key }) {
            sections.append(
                ReadingSection(
                    index: sections.count,
                    title: title,
                    startParagraphIndex: chapterStart + localIndex,
                    chapterIndex: chapterIndex
                )
            )
        }
        paragraphTexts.append(contentsOf: chapterParagraphs)
    }

    private static func splitParagraphText(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(
                of: "[\\t ]+",
                with: " ",
                options: .regularExpression
            )

        var pieces = normalized.components(separatedBy: "\n")
        pieces = pieces.map(cleanParagraph).filter { !$0.isEmpty }

        return pieces.flatMap(splitLongParagraph)
    }

    private static func splitLongParagraph(_ text: String) -> [String] {
        guard text.count > 900 else { return [text] }

        let sentencePattern = #"(?<=[。！？.!?；;])"#
        let separated = text.replacingOccurrences(
            of: sentencePattern,
            with: "\u{001F}",
            options: .regularExpression
        )
        let sentences = separated.components(separatedBy: "\u{001F}")
        if sentences.count <= 1 {
            return stride(from: 0, to: text.count, by: 700).map { offset in
                let start = text.index(text.startIndex, offsetBy: offset)
                let end = text.index(start, offsetBy: min(700, text.distance(from: start, to: text.endIndex)))
                return String(text[start..<end])
            }
        }

        var result: [String] = []
        var buffer = ""
        for sentence in sentences where !sentence.isEmpty {
            if buffer.count + sentence.count > 700, !buffer.isEmpty {
                result.append(buffer)
                buffer = ""
            }
            buffer += sentence
        }
        if !buffer.isEmpty {
            result.append(buffer)
        }
        return result
    }

    private static func cleanParagraph(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "[ ]{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelyChapterHeading(_ text: String) -> Bool {
        let candidate = cleanParagraph(text)
        guard !candidate.isEmpty, candidate.count <= 48 else { return false }
        guard candidate.range(
            of: #"[。！？!?；;]$"#,
            options: .regularExpression
        ) == nil else {
            return false
        }

        let patterns = [
            #"^第[零〇一二三四五六七八九十百千万两0-9A-Za-z]{1,12}[章回卷部篇集].{0,28}$"#,
            #"(?i)^chapter\s+[0-9ivxlcdm]+(?:\s*[:：.\-—]\s*|\s+).{0,32}$"#,
            #"^[0-9]{1,3}、\s*.{1,36}$"#,
            #"^[0-9]{1,3}[.．]\s+.{1,36}$"#,
            #"^(序章|序言|前言|楔子|引子|目录|后记|尾声|结语|番外)(?:[：:\s].{0,30})?$"#
        ]
        return patterns.contains {
            candidate.range(of: $0, options: .regularExpression) != nil
        }
    }

    private static func isLikelySectionHeading(_ text: String) -> Bool {
        let candidate = cleanParagraph(text)
        guard !candidate.isEmpty, candidate.count <= 48 else { return false }
        guard candidate.range(
            of: #"[。！？!?；;]$"#,
            options: .regularExpression
        ) == nil else {
            return false
        }

        let patterns = [
            #"^第[零〇一二三四五六七八九十百千万两0-9A-Za-z]{1,12}节.{0,30}$"#,
            #"^[0-9]{1,3}(?:\.[0-9]{1,3}){1,3}(?:\s+|[、.．：:]\s*).{1,34}$"#,
            #"^[（(][零〇一二三四五六七八九十百0-9]{1,8}[）)]\s*.{1,36}$"#,
            #"^[一二三四五六七八九十]{1,4}、\s*.{1,38}$"#
        ]
        return patterns.contains {
            candidate.range(of: $0, options: .regularExpression) != nil
        }
    }

    private static func inferredChapterTitle(
        from paragraphs: [String],
        fallbackNumber: Int
    ) -> String {
        if let first = paragraphs.first,
           first.count <= 48,
           isLikelyChapterHeading(first) {
            return first
        }
        return "第 \(fallbackNumber) 章"
    }

    private static func decodeText(_ data: Data) -> String? {
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        let big5 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.big5.rawValue)
            )
        )

        if let declaredEncoding = declaredTextEncoding(in: data),
           let string = String(data: data, encoding: declaredEncoding),
           !string.isEmpty {
            return string
        }

        let encodings: [String.Encoding] = [
            .utf8,
            gb18030,
            big5,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .unicode,
            .shiftJIS,
            .isoLatin1
        ]

        for encoding in encodings {
            if let string = String(data: data, encoding: encoding), !string.isEmpty {
                return string
            }
        }
        return nil
    }

    private static func declaredTextEncoding(in data: Data) -> String.Encoding? {
        let prefix = data.prefix(1_024)
        guard let header = String(data: prefix, encoding: .isoLatin1) else {
            return nil
        }
        let patterns = [
            #"(?i)\bencoding\s*=\s*["']\s*([^"']+)\s*["']"#,
            #"(?i)\bcharset\s*=\s*["']?\s*([A-Za-z0-9._-]+)"#
        ]

        var declaredName: String?
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: header,
                    range: NSRange(header.startIndex..., in: header)
                  ),
                  let range = Range(match.range(at: 1), in: header) else {
                continue
            }
            declaredName = String(header[range]).lowercased()
            break
        }

        guard let name = declaredName else { return nil }
        if name.contains("utf-8") || name == "utf8" {
            return .utf8
        }
        if name.contains("utf-16le") {
            return .utf16LittleEndian
        }
        if name.contains("utf-16be") {
            return .utf16BigEndian
        }
        if name.contains("utf-16") {
            return .utf16
        }
        if name.contains("gb") {
            return String.Encoding(
                rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                )
            )
        }
        if name.contains("big5") {
            return String.Encoding(
                rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.big5.rawValue)
                )
            )
        }
        if name.contains("shift_jis") || name.contains("shift-jis") {
            return .shiftJIS
        }
        return nil
    }

    private static func htmlToPlainText(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(
            of: "(?is)^.*?<body[^>]*>(.*?)</body>.*$",
            with: "$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "(?is)<(script|style|svg)[^>]*>.*?</\\1>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "(?i)<br\\s*/?>",
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "(?i)</?(p|div|h[1-6]|li|blockquote|section|article|tr)[^>]*>",
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        return decodeHTMLEntities(text)
    }

    private static func extractHTMLChapterTitle(_ html: String) -> String? {
        let patterns = [
            #"(?is)<h1\b[^>]*>(.*?)</h1>"#,
            #"(?is)<h2\b[^>]*>(.*?)</h2>"#,
            #"(?is)<title\b[^>]*>(.*?)</title>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: html,
                    range: NSRange(html.startIndex..., in: html)
                  ),
                  let range = Range(match.range(at: 1), in: html) else {
                continue
            }

            let title = decodeHTMLEntities(
                String(html[range]).replacingOccurrences(
                    of: "<[^>]+>",
                    with: "",
                    options: .regularExpression
                )
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            if !title.isEmpty, !isMachineGeneratedTitle(title) {
                return title
            }
        }
        return nil
    }

    private static func isMachineGeneratedTitle(_ title: String) -> Bool {
        let candidate = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.count >= 12 else { return false }
        let isIdentifier = candidate.range(
            of: #"^[A-Za-z0-9_.-]+$"#,
            options: .regularExpression
        ) != nil
        let digitCount = candidate.filter(\.isNumber).count
        return isIdentifier && digitCount >= 5
    }

    private static func extractHTMLSectionTitles(_ html: String) -> [String] {
        let pattern = #"(?is)<h[23]\b[^>]*>(.*?)</h[23]>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        return regex.matches(
            in: html,
            range: NSRange(html.startIndex..., in: html)
        ).compactMap { match in
            guard let range = Range(match.range(at: 1), in: html) else {
                return nil
            }
            let title = decodeHTMLEntities(
                String(html[range]).replacingOccurrences(
                    of: "<[^>]+>",
                    with: "",
                    options: .regularExpression
                )
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        }
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let namedEntities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'"
        ]
        for (entity, value) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: value)
        }

        let pattern = #"&#(x?[0-9A-Fa-f]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }
        let matches = regex.matches(
            in: result,
            range: NSRange(result.startIndex..., in: result)
        ).reversed()

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let valueRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            let raw = String(result[valueRange])
            let number: UInt32?
            if raw.lowercased().hasPrefix("x") {
                number = UInt32(raw.dropFirst(), radix: 16)
            } else {
                number = UInt32(raw, radix: 10)
            }
            if let number, let scalar = UnicodeScalar(number) {
                result.replaceSubrange(fullRange, with: String(scalar))
            }
        }
        return result
    }

    private static func recursiveHTMLFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return enumerator.compactMap { $0 as? URL }
            .filter { ["html", "htm", "xhtml"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.path < $1.path }
    }
}

private final class ContainerXMLParser: NSObject, XMLParserDelegate {
    private var rootfilePath: String?

    func parse(data: Data) -> String? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return rootfilePath
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName.lowercased().hasSuffix("rootfile") {
            rootfilePath = attributeDict["full-path"]
        }
    }
}

private final class PackageXMLParser: NSObject, XMLParserDelegate {
    struct ManifestItem {
        let href: String
        let mediaType: String
        let properties: String
    }

    struct Package {
        var manifest: [String: ManifestItem] = [:]
        var spine: [String] = []
        var title: String?
        var tocID: String?
    }

    private var package = Package()
    private var isReadingTitle = false
    private var titleBuffer = ""

    func parse(data: Data) -> Package {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return package
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.split(separator: ":").last?.lowercased() ?? ""
        switch localName {
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                package.manifest[id] = ManifestItem(
                    href: href,
                    mediaType: attributeDict["media-type"] ?? "",
                    properties: attributeDict["properties"] ?? ""
                )
            }
        case "spine":
            package.tocID = attributeDict["toc"]
        case "itemref":
            if let idref = attributeDict["idref"] {
                package.spine.append(idref)
            }
        case "title":
            isReadingTitle = true
            titleBuffer = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingTitle {
            titleBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.split(separator: ":").last?.lowercased() ?? ""
        if localName == "title" {
            isReadingTitle = false
            if package.title == nil {
                package.title = titleBuffer
            }
        }
    }
}

private final class NavigationXMLParser: NSObject, XMLParserDelegate {
    private struct NavigationPoint {
        var title = ""
        var href = ""
    }

    private var stack: [NavigationPoint] = []
    private var entries: [(href: String, title: String)] = []
    private var isReadingLabelText = false

    func parse(data: Data) -> [(href: String, title: String)] {
        stack = []
        entries = []
        isReadingLabelText = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return entries
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.split(separator: ":").last?.lowercased() ?? ""
        switch localName {
        case "navpoint":
            stack.append(NavigationPoint())
        case "text":
            if !stack.isEmpty {
                isReadingLabelText = true
            }
        case "content":
            if !stack.isEmpty, let source = attributeDict["src"] {
                stack[stack.count - 1].href = source
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingLabelText, !stack.isEmpty {
            stack[stack.count - 1].title += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.split(separator: ":").last?.lowercased() ?? ""
        switch localName {
        case "text":
            isReadingLabelText = false
        case "navpoint":
            guard let point = stack.popLast() else { return }
            let title = point.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !point.href.isEmpty, !title.isEmpty {
                entries.append((point.href, title))
            }
        default:
            break
        }
    }
}
