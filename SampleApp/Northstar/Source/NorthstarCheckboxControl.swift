//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

extension UIImage {
    fileprivate static let checkboxImageOn = UIImage(named: "ios-icon-checkbox-on", in: NorthstarCheckboxControl.bundle, compatibleWith: nil)
    fileprivate static let checkboxImageOff = UIImage(named: "ios-icon-checkbox-off", in: NorthstarCheckboxControl.bundle, compatibleWith: nil)
}

private let paragraphStyle: NSParagraphStyle = {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = .lineHeightBody
    paragraphStyle.maximumLineHeight = .lineHeightBody
    return paragraphStyle
}()

public final class NorthstarCheckboxControl: UIControl, NorthstarLoadable {
    @IBOutlet private weak var checkboxImageView: UIImageView!
    @IBOutlet private weak var descriptionLabel: NorthstarLabel!

    public var text: String = "" {
        didSet {
            let attributes = [NSParagraphStyleAttributeName: paragraphStyle]
            descriptionLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
        }
    }

    override public var isSelected: Bool {
        get { return super.isSelected }
        set {
            super.isSelected = newValue
            updateCheckbox()
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedSetup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedSetup()
    }

    private func sharedSetup() {
        loadContentsFromResource()
        descriptionLabel.textStyle = .body(.defaultColor)
        descriptionLabel.text = nil
        updateCheckbox()

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    @objc private func tapped() {
        isSelected = !isSelected
        updateCheckbox()
    }

    private func updateCheckbox() {
        checkboxImageView.image = isSelected ? .checkboxImageOn : .checkboxImageOff
        checkboxImageView.tintColor = isSelected ? .northstarPrimary : .northstarSoft
    }
}
