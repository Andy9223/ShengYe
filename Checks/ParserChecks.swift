import Foundation
import CoreFoundation

@main
struct ParserChecks {
    static func main() {
        checkParagraphNormalization()
        checkSentenceSplitting()
        checkTrackpadPagingGesture()
        checkResponsivePagination()
        checkLongParagraphSplitting()
        checkChapterRecognition()
        checkSectionRecognition()
        checkGB18030TextLoading()
        checkEPUBLoading()
        inspectRealEPUBWhenRequested()
        print("Parser checks passed.")
    }

    private static func checkParagraphNormalization() {
        let input = """
        第一段。


        第二段。
          第三段。
        """

        let paragraphs = DocumentLoader.makeParagraphs(from: input)
        precondition(
            paragraphs.map(\.text) == ["第一段。", "第二段。", "第三段。"],
            "自然段标准化失败"
        )
        precondition(
            paragraphs.map(\.index) == [0, 1, 2],
            "自然段编号失败"
        )
    }

    private static func checkSentenceSplitting() {
        let text = "第一句话。第二句话！Is this the third sentence?"
        let sentences = SentenceSplitter.split(text)

        precondition(sentences.count == 3, "句子切分数量失败")
        precondition(
            sentences.map(\.text).joined() == text,
            "句子切分丢失文字"
        )
        precondition(
            sentences[1].range.location == ("第一句话。" as NSString).length,
            "句子 UTF-16 起始位置错误"
        )
    }

    private static func checkResponsivePagination() {
        var paragraphs = (0..<24).map { index in
            ReadingParagraph(
                index: index,
                text: "这是第\(index + 1)段测试文字。调整字号以后，当前页面应当立即重新排版，并且不需要上下滚动。"
            )
        }
        paragraphs.append(
            ReadingParagraph(
                index: paragraphs.count,
                text: String(repeating: "超长句测试文字", count: 80) + "。"
            )
        )
        let document = ReadingDocument(
            title: "分页测试",
            sourceURL: nil,
            paragraphs: paragraphs,
            chapters: [
                ReadingChapter(
                    index: 0,
                    title: "第一章",
                    startParagraphIndex: 0
                )
            ],
            sections: [
                ReadingSection(
                    index: 0,
                    title: "第一章",
                    startParagraphIndex: 0,
                    chapterIndex: 0
                )
            ]
        )
        let layout = ReaderPageLayout(width: 620, height: 410)
        let smallFontPages = ReadingPaginator.paginate(
            document: document,
            fontSize: 16,
            layout: layout
        )
        let largeFontPages = ReadingPaginator.paginate(
            document: document,
            fontSize: 32,
            layout: layout
        )

        precondition(
            largeFontPages.count > smallFontPages.count,
            "字号变大后页面数量没有增加"
        )
        precondition(
            largeFontPages.allSatisfy { !$0.fragments.isEmpty },
            "响应式分页生成了空白页"
        )

        for paragraph in paragraphs {
            let rebuilt = largeFontPages
                .flatMap(\.fragments)
                .filter { $0.paragraphIndex == paragraph.index }
                .map {
                    (paragraph.text as NSString).substring(with: $0.range)
                }
                .joined()
            precondition(
                rebuilt == paragraph.text,
                "响应式分页丢失了第 \(paragraph.index + 1) 段文字"
            )
        }
    }

    private static func checkTrackpadPagingGesture() {
        var gesture = TrackpadPageGesture()
        precondition(
            gesture.consume(
                horizontalDelta: -24,
                verticalDelta: 2,
                timestamp: 1,
                began: true,
                ended: false
            ) == nil,
            "触控板手势过早翻页"
        )
        precondition(
            gesture.consume(
                horizontalDelta: -24,
                verticalDelta: 1,
                timestamp: 1.05,
                began: false,
                ended: false
            ) == .next,
            "两指向左滑没有进入下一页"
        )
        precondition(
            gesture.consume(
                horizontalDelta: -60,
                verticalDelta: 0,
                timestamp: 1.1,
                began: false,
                ended: false
            ) == nil,
            "一次触控板手势翻动了多页"
        )
        _ = gesture.consume(
            horizontalDelta: 0,
            verticalDelta: 0,
            timestamp: 1.2,
            began: false,
            ended: true
        )
        precondition(
            gesture.consume(
                horizontalDelta: 45,
                verticalDelta: 2,
                timestamp: 2,
                began: true,
                ended: false
            ) == .previous,
            "两指向右滑没有返回上一页"
        )
        precondition(
            gesture.consume(
                horizontalDelta: 3,
                verticalDelta: 50,
                timestamp: 3,
                began: true,
                ended: false
            ) == nil,
            "纵向触控板滚动误触发翻页"
        )
    }

    private static func checkLongParagraphSplitting() {
        let sentence = "这是一句用于测试自动分段的文字。"
        let input = String(repeating: sentence, count: 80)
        let paragraphs = DocumentLoader.makeParagraphs(from: input)

        precondition(paragraphs.count > 1, "长段落没有拆分")
        precondition(
            paragraphs.allSatisfy { $0.text.count <= 720 },
            "拆分后的自然段过长"
        )
        precondition(
            paragraphs.map(\.text).joined() == input,
            "拆分过程丢失了文本"
        )
    }

    private static func checkChapterRecognition() {
        let text = (1...11).map { number in
            "第\(number)章 测试章节\n这是第\(number)章的正文内容。"
        }.joined(separator: "\n\n")

        let paragraphs = DocumentLoader.makeParagraphs(from: text)
        let chapters = DocumentLoader.makeChapters(from: paragraphs)

        precondition(chapters.count == 11, "TXT 章节数量识别失败")
        precondition(chapters[5].title == "第6章 测试章节", "第六章标题识别失败")
        precondition(
            paragraphs[chapters[5].startParagraphIndex].text == "第6章 测试章节",
            "第六章起始位置识别失败"
        )
        let sections = DocumentLoader.makeSections(
            from: paragraphs,
            chapters: chapters
        )
        precondition(sections.count == 11, "无小节书籍的章节退化逻辑失败")
    }

    private static func checkSectionRecognition() {
        let text = """
        第一章 起点
        章首内容。
        第一节 背景
        第一节正文。
        1.2 新的线索
        第二节正文。
        第二章 继续
        第二章正文。
        """
        let paragraphs = DocumentLoader.makeParagraphs(from: text)
        let chapters = DocumentLoader.makeChapters(from: paragraphs)
        let sections = DocumentLoader.makeSections(
            from: paragraphs,
            chapters: chapters
        )

        precondition(
            chapters.count == 2,
            "小节被错误识别为章节：\(chapters.map(\.title))"
        )
        precondition(sections.count == 4, "TXT 小节数量识别失败")
        precondition(sections[1].title == "第一节 背景", "中文小节标题识别失败")
        precondition(sections[2].title == "1.2 新的线索", "数字小节标题识别失败")
    }

    private static func checkGB18030TextLoading() {
        let encoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        let source = "第一章 中文编码\n这是 GB18030 正文。"
        guard let data = source.data(using: encoding) else {
            preconditionFailure("无法生成 GB18030 测试数据")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicePage-GB18030-\(UUID().uuidString).txt")
        do {
            try data.write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            let document = try DocumentLoader.load(from: url)
            precondition(
                document.paragraphs.first?.text == "第一章 中文编码",
                "GB18030 标题解码失败"
            )
            precondition(
                document.paragraphs.last?.text.contains("正文") == true,
                "GB18030 正文解码失败"
            )
        } catch {
            preconditionFailure("GB18030 文件加载失败：\(error.localizedDescription)")
        }
    }

    private static func checkEPUBLoading() {
        guard let path = ProcessInfo.processInfo.environment["VOICEPAGE_TEST_EPUB"] else {
            preconditionFailure("缺少 EPUB 测试文件路径")
        }

        do {
            let document = try DocumentLoader.load(from: URL(fileURLWithPath: path))
            precondition(document.title == "声页测试书", "EPUB 书名解析失败")
            precondition(document.paragraphs.count == 6, "EPUB 正文段落解析失败")
            precondition(
                document.paragraphs[1].text.contains("自动翻页"),
                "EPUB 正文内容解析失败"
            )
            precondition(document.chapters.count == 2, "EPUB 章节数量解析失败")
            precondition(
                document.chapters[0].title == "第一章 正确目录标题",
                "EPUB Navigation 第一章标题解析失败"
            )
            precondition(
                document.chapters[1].title == "第二章 正确目录标题",
                "EPUB Navigation 第二章标题解析失败"
            )
            precondition(
                document.chapters[1].startParagraphIndex == 4,
                "EPUB 第二章位置解析失败"
            )
            precondition(document.sections.count == 3, "EPUB 小节数量解析失败")
            precondition(document.sections[1].title == "自动翻页", "EPUB 小节标题解析失败")
        } catch {
            preconditionFailure("EPUB 加载失败：\(error.localizedDescription)")
        }
    }

    private static func inspectRealEPUBWhenRequested() {
        guard let path = ProcessInfo.processInfo.environment["VOICEPAGE_REAL_EPUB"] else {
            return
        }
        do {
            let document = try DocumentLoader.load(from: URL(fileURLWithPath: path))
            print("Real EPUB title:", document.title)
            print("Real EPUB chapters:", document.chapters.map(\.title))
        } catch {
            preconditionFailure("真实 EPUB 检查失败：\(error.localizedDescription)")
        }
    }
}
