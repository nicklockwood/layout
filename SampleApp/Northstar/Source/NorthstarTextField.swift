//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public final class NorthstarTextField: UITextField {
    private let defaultBackgroundColor = UIColor.northstarSoft.withAlphaComponent(0.05)
    private let defaultBorderColor = UIColor.northstarSoft.withAlphaComponent(0.3)
    private let disabledTextColor = UIColor.northstarSoft.withAlphaComponent(0.5)

    private var isInFocus = false {
        didSet {
            assert(Thread.isMainThread)
            updateBorder()
            updateBackgroundColor()
        }
    }

    public override var text: String? {
        didSet {
            updateBackgroundColor()
        }
    }

    public override var placeholder: String? {
        didSet {
            updatePlaceholder(with: placeholder)
        }
    }

    public override var isEnabled: Bool {
        didSet {
            assert(Thread.isMainThread)
            updateBorder()
            updatePlaceholder(with: placeholder)
            updateTextColor()
        }
    }

    public var isInErrorMode = false {
        didSet {
            assert(Thread.isMainThread)
            updateBorder()
            updateBackgroundColor()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupUIAppearance()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setupUIAppearance()
    }

    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: .paddingDefault, dy: 0)
    }

    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let textRect = self.textRect(forBounds: bounds)

        return CGRect(origin: textRect.origin, size: CGSize(width: textRect.width - .paddingDefault, height: textRect.height))
    }

    public override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        return super.clearButtonRect(forBounds: bounds).offsetBy(dx: -(.paddingSmall), dy: 0)
    }

    private func setupUIAppearance() {
        updateTextColor()
        updateBorder()
        updateBackgroundColor()
        tintColor = .northstarPrimary
        font = .body
        borderStyle = .none
        cornerRadius = 4
        borderWidth = 1

        addTarget(self, action: #selector(textFieldDidBeginEditing), for: .editingDidBegin)
        addTarget(self, action: #selector(textFieldDidEndEditing), for: .editingDidEnd)
    }

    @objc private func textFieldDidBeginEditing(_: UITextField) {
        isInFocus = true
    }

    @objc private func textFieldDidEndEditing(_: UITextField) {
        isInFocus = false
    }

    private func updateBorder() {
        guard isEnabled else {
            borderColor = .clear
            return
        }

        guard !isInErrorMode else {
            borderColor = .northstarError
            return
        }

        borderColor = isInFocus ? .northstarPrimary : defaultBorderColor
    }

    private func updateBackgroundColor() {
        guard !isInErrorMode else {
            backgroundColor = UIColor.northstarError.withAlphaComponent(0.05)
            return
        }

        if let text = text, !text.isEmpty {
            backgroundColor = .white
        } else if isInFocus {
            backgroundColor = .white
        } else {
            backgroundColor = defaultBackgroundColor
        }
    }

    private func updatePlaceholder(with placeholder: String?) {
        guard let placeholder = placeholder else { return }

        let placeholderColor = isEnabled ? UIColor.northstarSoft : disabledTextColor
        let placeholderAttributes = [NSForegroundColorAttributeName: placeholderColor]
        attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttributes)
    }

    private func updateTextColor() {
        textColor = isEnabled ? .northstarDark : disabledTextColor
    }
}
