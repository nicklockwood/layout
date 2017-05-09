//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

extension NorthstarSubmitInputView: NorthstarLoadable {}

public final class NorthstarSubmitInputView: UIControl {
    @IBOutlet private weak var submitButton: NorthstarButton!
    @IBOutlet private weak var dimView: UIView!

    private var defaultBackgroundColor: UIColor?

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
        dimView.backgroundColor = .northstarDim
        defaultBackgroundColor = backgroundColor
    }

    public dynamic var title: String = "" {
        didSet {
            submitButton.setTitle(self.title, for: .normal)
        }
    }

    public dynamic var isPrimary: Bool = true {
        didSet {
            submitButton.isPrimary = isPrimary
        }
    }

    public override dynamic var isEnabled: Bool {
        didSet {
            submitButton.isEnabled = isEnabled
        }
    }

    public override func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControlEvents = .touchUpInside) {
        submitButton.addTarget(target, action: action, for: controlEvents)
    }

    public func startDimming() {
        backgroundColor = .white
        dimView.isHidden = false
    }

    public func stopDimming() {
        backgroundColor = defaultBackgroundColor
        dimView.isHidden = true
    }
}
