//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public class NorthstarTextView: UITextView {

    private static let defaultTextStyle = NorthstarTextStyle.bodyAlt(.defaultColor)

    private var hasConstructed = false

    public var textStyle = NorthstarTextView.defaultTextStyle {
        didSet {
            updateAttributedText()
        }
    }

    public override var text: String? {
        didSet {
            updateAttributedText()
        }
    }

    // NB: super.init explicitly sets the font and textColor from values in the NIB
    // so we can't assert during construction.
    public override var font: UIFont? {
        didSet {
            guard hasConstructed else { return }
            assertionFailure("Use textStyle instead")
        }
    }

    public override var textColor: UIColor? {
        didSet {
            guard hasConstructed else { return }
            assertionFailure("Use textStyle instead")
        }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)

        configure()
    }

    private func configure() {
        removePadding()

        // NB: super.init explicitly sets the font and textColor from values in the NIB
        // so we reset them here to ensure our defaults are initially set.
        textStyle = NorthstarTextView.defaultTextStyle
        hasConstructed = true
    }

    private func removePadding() {
        textContainer.lineFragmentPadding = 0.0
        textContainerInset = .zero
    }

    private func updateAttributedText() {
        guard let text = text else { return }
        var attributes = textStyle.northstarTextAttributes
        attributes.lineBreakMode = .byWordWrapping
        attributedText = NSAttributedString(string: text, northstarTextAttributes: attributes)
    }
}
