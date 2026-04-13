import UIKit
import UIKitExtensions

public final class LinkLabel: UILabel {

    public override var lineBreakMode: NSLineBreakMode {
        didSet {
            self.textContainer?.lineBreakMode = self.lineBreakMode
        }
    }

    public override var numberOfLines: Int {
        didSet {
            self.textContainer?.maximumNumberOfLines = self.numberOfLines
        }
    }

    public override var attributedText: NSAttributedString? {
        set {
            guard let mutableCopy = newValue?.mutableCopy() as? NSMutableAttributedString else {
                return
            }

            mutableCopy.removeAttribute(.link, range: NSRange(location: 0, length: mutableCopy.length))

            super.attributedText = mutableCopy

            self.textStorage.setAttributedString(mutableCopy)
        }

        get {
            super.attributedText
        }
    }

    public weak var delegate: LinkLabelDelegate?

    private var textContainer: NSTextContainer? {
        self.layoutManager.textContainers.first
    }

    private var highlightColorAttribute: LinkAttribute? {
        willSet {
            if newValue == self.highlightColorAttribute {
                return
            }
        }

        didSet {
            self.setNeedsDisplay()
        }
    }

    private let layoutManager = NSLayoutManager()

    private let textStorage = NSTextStorage()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.setUpLayoutManager()
        self.setUpTextStorage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()

        self.textContainer?.size = self.bounds.size
    }

    public override func drawText(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.saveGState()

        if let highlightColorAttribute, highlightColorAttribute.range.length > 0 {
            let fill: (CGRect) -> Void = { rect in
                guard let color = highlightColorAttribute.value as? UIColor else {
                    return
                }

                color.setFill()

                let padding: CGFloat = 4
                UIBezierPath(roundedRect: CGRect(x: rect.minX ,
                                                 y: rect.minY,
                                                 width: rect.width,
                                                 height: rect.height ),
                             cornerRadius: padding)
                .fill()
            }

            if highlightColorAttribute.lineFrames.count > 0 {
                for rect in highlightColorAttribute.lineFrames {
                    fill(rect)
                }
            } else {
                fill(highlightColorAttribute.mainFrame)
            }
        }

        context.restoreGState()

        self.layoutManager.drawGlyphs(forGlyphRange: NSRange(location: 0, length: self.textStorage.length),
                                      at: .zero)
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.updateHighlightedAttribute(for: touches)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.updateHighlightedAttribute(for: touches)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.highlightColorAttribute = nil
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            self.highlightColorAttribute = nil
        }

        guard let attributedText,
              let highlightColorAttribute,
              highlightColorAttribute.range.length > 0,
              let link = attributedText.attribute(CustomAttributedStringKeys.link,
                                                  at: highlightColorAttribute.range.location,
                                                  effectiveRange: nil) as? URL else {
            return
        }

        self.delegate?.labelDidDetectLink(self, link: link)
    }

    private func setUpLayoutManager() {
        let textContainer = NSTextContainer(size: self.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = self.numberOfLines
        textContainer.lineBreakMode = self.lineBreakMode
        textContainer.layoutManager = self.layoutManager

        self.layoutManager.addTextContainer(textContainer)
    }

    private func setUpTextStorage() {
        self.textStorage.addLayoutManager(self.layoutManager)
    }

    private func updateHighlightedAttribute(for touches: Set<UITouch>) {
        guard let location = touches.first?.location(in: self) else {
            return
        }

        self.highlightColorAttribute = self.attributes(at: location)[CustomAttributedStringKeys.highlightedLinkBackgroundColor]
    }

    private func attributes(at point: CGPoint) -> [NSAttributedString.Key: LinkAttribute] {
        guard let textContainer else {
            return [:]
        }

        var point = point

        let glyphsRect = self.layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: self.layoutManager.numberOfGlyphs),
                                                         in: textContainer)

        let bounds = self.bounds
        if bounds.height > glyphsRect.height {
            point.y -= (bounds.height - glyphsRect.height) / 2
        }

        if !glyphsRect.contains(point) {
            return [:]
        }

        let characterIndex = self.layoutManager.characterIndex(for: point,
                                                               in: textContainer,
                                                               fractionOfDistanceBetweenInsertionPoints: nil)

        var result = [NSAttributedString.Key: LinkAttribute]()

        if let attributedText, characterIndex < self.textStorage.length {
            let attributes = attributedText.attributes(at: characterIndex, effectiveRange: nil)
            let range = NSRange(location: 0, length: attributedText.length)

            for (key, value) in attributes {
                var effectiveRange = NSRange(location: 0, length: 0)

                if attributedText.attribute(key,
                                            at: characterIndex,
                                            longestEffectiveRange: &effectiveRange,
                                            in: range) != nil {
                    var lineFrames = [CGRect]()

                    self.layoutManager.enumerateLineFragments(forGlyphRange: effectiveRange) { rect, usedRect, textContainer, lineGlyphRange, stop in
                        let intersectionRange = effectiveRange.intersection(lineGlyphRange)

                        guard let intersectionRange, intersectionRange.length > 0 else {
                            return
                        }

                        let attributeRect = self.layoutManager.boundingRect(forGlyphRange: intersectionRange,
                                                                            in: textContainer)

                        var offsetRect = attributeRect

                        if bounds.height > glyphsRect.height {
                            offsetRect.origin.y += (bounds.height - glyphsRect.height) / 2
                        }

                        lineFrames.append(offsetRect)
                    }

                    var mainFrame = self.layoutManager.boundingRect(forGlyphRange: effectiveRange,
                                                                    in: textContainer)

                    if bounds.height > glyphsRect.height {
                        mainFrame.origin.y += (bounds.height - glyphsRect.height) / 2
                    }

                    result[key] = LinkAttribute(key: key,
                                                value: value,
                                                range: effectiveRange,
                                                lineFrames: lineFrames,
                                                mainFrame: mainFrame)
                }
            }
        }

        return result
    }

}
