//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension UIScrollView {

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["contentInsetAdjustmentBehavior"] = RuntimeType(Int.self, [
            "automatic": 0,
            "scrollableAxes": 1,
            "never": 2,
            "always": 3,
        ] as [String: Int])
        #if swift(>=3.2)
            if #available(iOS 11.0, *) {
                types["contentInsetAdjustmentBehavior"] = RuntimeType(UIScrollViewContentInsetAdjustmentBehavior.self, [
                    "automatic": .automatic,
                    "scrollableAxes": .scrollableAxes,
                    "never": .never,
                    "always": .always,
                ] as [String: UIScrollViewContentInsetAdjustmentBehavior])
            }
        #endif
        types["indicatorStyle"] = RuntimeType(UIScrollViewIndicatorStyle.self, [
            "default": .default,
            "black": .black,
            "white": .white,
        ] as [String: UIScrollViewIndicatorStyle])
        types["indexDisplayMode"] = RuntimeType(UIScrollViewIndexDisplayMode.self, [
            "automatic": .automatic,
            "alwaysHidden": .alwaysHidden,
        ] as [String: UIScrollViewIndexDisplayMode])
        types["keyboardDismissMode"] = RuntimeType(UIScrollViewKeyboardDismissMode.self, [
            "none": .none,
            "onDrag": .onDrag,
            "interactive": .interactive,
        ] as [String: UIScrollViewKeyboardDismissMode])
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "contentInsetAdjustmentBehavior":
            if #available(iOS 11.0, *) {
                fallthrough
            }
            // Does nothing on iOS 10 and earlier
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didUpdateLayout(for node: LayoutNode) {
        guard classForCoder == UIScrollView.self else {
            return // Skip this behavior for subclasses like UITableView
        }
        // Update contentSize
        contentSize = node.contentSize
        // Prevents contentOffset glitch when rotating from portrait to landscape
        if isPagingEnabled {
            let offset = CGPoint(
                x: round(contentOffset.x / frame.size.width) * frame.size.width - contentInset.left,
                y: round(contentOffset.y / frame.size.height) * frame.size.height - contentInset.top
            )
            guard !offset.x.isNaN && !offset.y.isNaN else { return }
            contentOffset = offset
        }
    }
}
