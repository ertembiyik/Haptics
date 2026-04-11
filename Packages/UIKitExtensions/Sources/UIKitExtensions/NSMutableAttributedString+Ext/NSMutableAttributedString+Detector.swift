import UIKit

public extension NSMutableAttributedString {

    private static let linksDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    private static let wikiLinksDetector: NSRegularExpression? = {
        let pattern = "\\[((https?://)?[^\\|\\[]+)\\|([^\\]]+)\\]"
        return try? NSRegularExpression(pattern: pattern)
    }()

    func detectLinks(with options: DetectorOption, attributes: [NSAttributedString.Key: Any]) {
        guard self.length > 0 else {
            return
        }

        var indexSet = NSMutableIndexSet()

        if options.contains(.link) {
            self.detectAndReplaceWIKILinks(with: &indexSet, attributes: attributes)
            self.detectAndReplaceLinks(with: &indexSet, attributes: attributes)
        }
    }

    private func detectAndReplaceWIKILinks(with ranges: inout NSMutableIndexSet, attributes: [NSAttributedString.Key: Any]) {
        guard let wikiLinksDetector = Self.wikiLinksDetector else {
            return
        }

        self.detectAndReplaceLinks(with: wikiLinksDetector, nameRangeIndex: 3, ranges: &ranges, attributes: attributes)
    }

    private func detectAndReplaceLinks(with ranges: inout NSMutableIndexSet, attributes: [NSAttributedString.Key: Any]) {
        let string = self.string

        guard !string.isEmpty, let linksDetector = Self.linksDetector else {
            return
        }

        var results = [NSTextCheckingResult]()

        self.detectData(in: string,
                        detector: linksDetector) { _, result, _ in
            results.insert(result, at: 0)
        }

        for result in results {
            let range = result.range

            guard !ranges.contains(in: range) else {
                continue
            }

            var hasLink = false
            self.enumerateAttribute(.link, in: range) { value, range, stop in
                hasLink = value != nil
                stop.pointee = value != nil ? true : false
            }

            if hasLink {
                continue
            }

            guard let url = result.url else {
                continue
            }

            self.highlight(url: url, range: range, attributes: attributes)

            ranges.add(in: range)
        }
    }

    private func detectAndReplaceLinks(with regularExpression: NSRegularExpression,
                                       nameRangeIndex: Int,
                                       ranges: inout NSMutableIndexSet,
                                       attributes: [NSAttributedString.Key: Any]) {
        let string = self.string

        guard !string.isEmpty else {
            return
        }

        var results = [NSTextCheckingResult]()

        self.detectData(in: string,
                        detector: regularExpression) { _, result, _ in
            results.insert(result, at: 0)
        }

        results.sort { lhs, rhs in
            return lhs.range.location > rhs.range.location
        }

        for result in results {
            let range = result.range

            guard !ranges.contains(in: range) else {
                continue
            }

            let urlRange = result.range(at: 1)
            let nameRange = result.range(at: nameRangeIndex)

            guard urlRange.location != NSNotFound,
                  let stringRange = Range(urlRange, in: string) else {
                continue
            }

            let absoluteUrl = String(string[stringRange])

            guard let url = if #available(iOS 17.0, *) {
                URL(string: absoluteUrl, encodingInvalidCharacters: false)
            } else {
                URL(string: absoluteUrl)
            } else {
                continue
            }

            guard nameRange.location != NSNotFound,
                  let stringRange = Range(nameRange, in: string) else {
                continue
            }

            let name = String(string[stringRange])

            let mentionRange = NSRange(location: result.range.location, length: nameRange.length)

            self.replaceCharacters(in: result.range, with: name)

            self.highlight(url: url, range: mentionRange, attributes: attributes)

            ranges.shiftIndexesStarting(at: mentionRange.location + mentionRange.length,
                                        by: mentionRange.length - result.range.length)

            ranges.add(in: mentionRange)
        }
    }

    private func detectData(in string: String,
                            detector: NSRegularExpression,
                            using block: (String, NSTextCheckingResult, NSRegularExpression.MatchingFlags) -> Void) {
        let startDate = Date()

        detector.enumerateMatches(in: string,
                                  options: .reportProgress,
                                  range: NSRange(location: 0, length: string.count)) { result, flags, stop in
            guard let result else {
                if startDate.timeIntervalSinceNow < -0.3 {
                    stop.pointee = true
                }

                return
            }

            block(string, result, flags)
        }
    }

}

