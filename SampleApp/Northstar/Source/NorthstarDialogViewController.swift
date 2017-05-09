//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public protocol NorthstarDialogProtocol: class {
    func shouldDismiss()
}

extension NorthstarDialogViewController: NorthstarLoadable {}

public final class NorthstarDialogViewController: UIViewController {

    @IBOutlet private weak var dialogContainerView: UIView!
    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var titleLabel: NorthstarLabel!
    @IBOutlet private weak var messageLabel: NorthstarLabel!
    @IBOutlet private weak var okButton: NorthstarButton!

    private var dialogTitle: String?
    private var dialogMessage: String?
    private var dialogDismiss: String?
    private var logoImage: UIImage?
    public weak var delegate: NorthstarDialogProtocol?

    public override func viewDidLoad() {
        super.viewDidLoad()

        clearContent()
        setupUIAppearance()
        enableTapToDismiss()
    }

    @IBAction func didTapOkButton(_: Any) {
        delegate?.shouldDismiss()
    }

    public func setup(withTitle title: String, message: String, dismiss: String, logoImage: UIImage) {
        dialogTitle = title
        dialogMessage = message
        dialogDismiss = dismiss
        self.logoImage = logoImage
    }

    private func clearContent() {
        logoImageView.image = nil
        titleLabel.text = nil
        messageLabel.text = nil
    }

    private func setupUIAppearance() {
        dialogContainerView.cornerRadius = 3.0

        titleLabel.textStyle = .heading1(.defaultColor)
        messageLabel.textStyle = .body(.colored(.northstarSoft))

        titleLabel.text = dialogTitle
        messageLabel.text = dialogMessage
        logoImageView.image = logoImage

        okButton.setTitle(dialogDismiss, for: .normal)
    }

    private func enableTapToDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissDialog(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissDialog(_ tap: UITapGestureRecognizer) {
        if case .ended = tap.state {
            let location = tap.location(in: view)

            let point = dialogContainerView.convert(location, from: view)
            if !dialogContainerView.point(inside: point, with: nil) {
                delegate?.shouldDismiss()
            }
        }
    }
}
