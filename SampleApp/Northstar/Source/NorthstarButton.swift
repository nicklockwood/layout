//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public final class NorthstarButton: UIButton {

    @IBInspectable var isPrimary: Bool = true {
        didSet {
            setupUIAppearance()
        }
    }

    private var defaultColor: UIColor {
        return isPrimary ? .northstarPrimary : .northstarSecondary
    }

    private var titleColor: UIColor {
        return isPrimary ? .northstarPrimaryButtonText : .northstarSecondaryButtonText
    }

    private let highlightedColor = UIColor.black.withAlphaComponent(0.3)

    public override var isEnabled: Bool {
        didSet {
            setupUIAppearance()
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setupUIAppearance()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupUIAppearance()
    }

    private func setupUIAppearance() {

        cornerRadius = 4
        clipsToBounds = true

        backgroundColor = isEnabled ? defaultColor : defaultColor.withAlphaComponent(0.4)
        setBackgroundImage(UIImage(color: highlightedColor, size: frame.size), for: .highlighted)

        titleLabel?.font = .body
        setTitleColor(titleColor, for: .normal)

        setNeedsDisplay()
    }
}
