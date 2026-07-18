import Foundation

enum ReadingPaginator {
    static func paginate(
        document: ReadingDocument,
        fontSize: Double,
        layout: ReaderPageLayout
    ) -> [ReadingPage] {
        guard !document.paragraphs.isEmpty else { return [] }

        let safeFontSize = min(max(fontSize, 12), 40)
        let characterWidth = safeFontSize * 1.03
        let lineHeight = safeFontSize * 1.72
        let charactersPerLine = max(
            Int(floor(layout.width / characterWidth)),
            8
        )
        let visibleLineCount = max(
            Int(floor(layout.height / lineHeight)),
            3
        )

        // 保留一行安全余量，避免 SwiftUI 和字体测量存在细微差异时出现裁切。
        let pageCapacity = max(
            charactersPerLine * max(visibleLineCount - 1, 2),
            20
        )
        let firstParagraphCost = max(
            Int((Double(charactersPerLine) * 0.75).rounded(.up)),
            4
        )
        let paragraphBreakCost = max(
            Int((Double(charactersPerLine) * 1.35).rounded(.up)),
            6
        )
        let chapterStarts = Set(
            document.chapters.dropFirst().map(\.startParagraphIndex)
        )

        var pages: [ReadingPage] = []
        var pageFragments: [ReadingPageFragment] = []
        var usedCapacity = 0
        var lastParagraphIndex: Int?

        func finishPage() {
            guard !pageFragments.isEmpty else { return }
            pages.append(
                ReadingPage(number: pages.count, fragments: pageFragments)
            )
            pageFragments = []
            usedCapacity = 0
            lastParagraphIndex = nil
        }

        func prepareParagraph(_ paragraphIndex: Int) {
            let cost = pageFragments.isEmpty
                ? firstParagraphCost
                : paragraphBreakCost
            if !pageFragments.isEmpty, usedCapacity + cost >= pageCapacity {
                finishPage()
            }
            usedCapacity += firstParagraphCost
            if !pageFragments.isEmpty, lastParagraphIndex != nil {
                usedCapacity += max(paragraphBreakCost - firstParagraphCost, 0)
            }
            lastParagraphIndex = paragraphIndex
        }

        for paragraph in document.paragraphs {
            if chapterStarts.contains(paragraph.index), !pageFragments.isEmpty {
                finishPage()
            }

            prepareParagraph(paragraph.index)
            let sentences = SentenceSplitter.split(paragraph.text)

            for sentence in sentences {
                let sentenceCost = displayUnits(in: sentence.text)
                let freshPageTextCapacity = max(
                    pageCapacity - firstParagraphCost,
                    1
                )

                if sentenceCost <= freshPageTextCapacity {
                    if !pageFragments.isEmpty,
                       usedCapacity + sentenceCost > pageCapacity {
                        finishPage()
                        prepareParagraph(paragraph.index)
                    }
                    pageFragments.append(
                        ReadingPageFragment(
                            paragraphIndex: paragraph.index,
                            range: sentence.range,
                            sentenceStartOffset: sentence.range.location
                        )
                    )
                    usedCapacity += sentenceCost
                    continue
                }

                let nsSentence = sentence.text as NSString
                var consumedUTF16 = 0

                while consumedUTF16 < nsSentence.length {
                    let remainingCapacity = pageCapacity - usedCapacity
                    if remainingCapacity < max(pageCapacity / 5, 8),
                       !pageFragments.isEmpty {
                        finishPage()
                        prepareParagraph(paragraph.index)
                    }

                    let availableCapacity = max(
                        pageCapacity - usedCapacity,
                        1
                    )
                    let remainingText = nsSentence.substring(
                        from: consumedUTF16
                    )
                    let prefix = prefixFitting(
                        remainingText,
                        maximumUnits: availableCapacity
                    )
                    let fragmentLength = min(
                        max(prefix.utf16Length, 1),
                        nsSentence.length - consumedUTF16
                    )

                    pageFragments.append(
                        ReadingPageFragment(
                            paragraphIndex: paragraph.index,
                            range: NSRange(
                                location: sentence.range.location + consumedUTF16,
                                length: fragmentLength
                            ),
                            sentenceStartOffset: sentence.range.location
                        )
                    )
                    consumedUTF16 += fragmentLength
                    usedCapacity += prefix.units

                    if consumedUTF16 < nsSentence.length {
                        finishPage()
                        prepareParagraph(paragraph.index)
                    }
                }
            }
        }

        finishPage()
        return pages
    }

    private static func prefixFitting(
        _ text: String,
        maximumUnits: Int
    ) -> (utf16Length: Int, units: Int) {
        var totalUnits = 0.0
        var utf16Length = 0

        for character in text {
            let cost = displayUnits(for: character)
            if utf16Length > 0, totalUnits + cost > Double(maximumUnits) {
                break
            }
            totalUnits += cost
            utf16Length += String(character).utf16.count
        }

        if utf16Length == 0, let first = text.first {
            utf16Length = String(first).utf16.count
            totalUnits = displayUnits(for: first)
        }

        return (utf16Length, max(Int(ceil(totalUnits)), 1))
    }

    private static func displayUnits(in text: String) -> Int {
        max(
            Int(ceil(text.reduce(0.0) { $0 + displayUnits(for: $1) })),
            1
        )
    }

    private static func displayUnits(for character: Character) -> Double {
        guard character.unicodeScalars.allSatisfy(\.isASCII) else {
            return 1
        }
        if character.isWhitespace {
            return 0.35
        }
        return 0.58
    }
}
