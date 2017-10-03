//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

extension UIStackView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["axis"] = RuntimeType(UILayoutConstraintAxis.self, [
            "horizontal": .horizontal,
            "vertical": .vertical,
        ] as [String: UILayoutConstraintAxis])
        types["distribution"] = RuntimeType(UIStackViewDistribution.self, [
            "fill": .fill,
            "fillEqually": .fillEqually,
            "fillProportionally": .fillProportionally,
            "equalSpacing": .equalSpacing,
            "equalCentering": .equalCentering,
        ] as [String: UIStackViewDistribution])
        types["alignment"] = RuntimeType(UIStackViewAlignment.self, [
            "fill": .fill,
            "leading": .leading,
            "top": .top,
            "firstBaseline": .firstBaseline,
            "center": .center,
            "trailing": .trailing,
            "bottom": .bottom,
            "lastBaseline": .lastBaseline, // Valid for horizontal axis only
        ] as [String: UIStackViewAlignment])
        types["spacing"] = RuntimeType(CGFloat.self)
        types["arrangedSubviews"] = .unavailable()
        // UIStackView is a non-drawing view, so none of these properties are available
        for name in [
            "backgroundColor",
            "contentMode",
            "layer.backgroundColor",
            "layer.cornerRadius",
            "layer.borderColor",
            "layer.borderWidth",
            "layer.contents",
            "layer.masksToBounds",
            "layer.shadowColor",
            "layer.shadowOffset",
            "layer.shadowOffset.height",
            "layer.shadowOffset.width",
            "layer.shadowOpacity",
            "layer.shadowPath",
            "layer.shadowPathIsBounds",
            "layer.shadowRadius",
        ] {
            types[name] = .unavailable()
        }
        return types
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        super.didInsertChildNode(node, at: index)
        addArrangedSubview(node.view)
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        (node._view as UIView?).map(removeArrangedSubview)
        super.willRemoveChildNode(node, at: index)
    }
}
