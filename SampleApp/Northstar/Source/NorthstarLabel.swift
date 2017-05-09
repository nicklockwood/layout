//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

open class NorthstarLabel: UILabel {

    public var textStyle = NorthstarTextStyle.body(.defaultColor) {
        didSet {
            updateAttributedText()
        }
    }

    open override var text: String? {
        didSet {
            updateAttributedText()
        }
    }

    open override var font: UIFont? {
        didSet {
//            assertionFailure("Use textStyle instead")
        }
    }

    open override var textColor: UIColor? {
        didSet {
//            assertionFailure("Use textStyle instead")
        }
    }

    open override var textAlignment: NSTextAlignment {
        didSet {
            updateAttributedText()
        }
    }

    private func updateAttributedText() {
        guard let text = text else { return }
        var attributes = textStyle.northstarTextAttributes
        attributes.textAlignment = textAlignment
        attributes.lineBreakMode = lineBreakMode
        attributedText = NSAttributedString(string: text, northstarTextAttributes: attributes)
    }
}
