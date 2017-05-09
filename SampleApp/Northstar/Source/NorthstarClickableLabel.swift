//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public protocol NorthstarClickableLabelDelegate: class {
    func didTapLabel(_ label: NorthstarClickableLabel)
}

public final class NorthstarClickableLabel: NorthstarLabel {
    public weak var delegate: NorthstarClickableLabelDelegate?

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setupUIAppearance()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupUIAppearance()
    }

    private func setupUIAppearance() {
        textStyle = .body(.colored(.northstarPrimary))

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    @objc private func tapped() {
        delegate?.didTapLabel(self)
    }
}
