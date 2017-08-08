//
//  UIScrollView+Layout.swift
//  Layout
//
//  Created by Nick Lockwood on 08/08/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import Foundation

extension UIScrollView {

    // This property is not available on iOS 10 and earlier
    // But it's useful to be able to set it to `never` in order
    // to implement consistent behavior across iOS versions
    private enum ContentInsetAdjustmentBehavior: Int {
        case automatic, scrollableAxes, never, always
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        #if swift(>=3.2)
        if #available(iOS 11.0, *) {
            types["contentInsetAdjustmentBehavior"] = RuntimeType(UIScrollViewContentInsetAdjustmentBehavior.self, [
                "automatic": .automatic,
                "scrollableAxes": .scrollableAxes,
                "never": .never,
                "always": .always,
            ])
        }
        #endif
        if types["contentInsetAdjustmentBehavior"] == nil {
            types["contentInsetAdjustmentBehavior"] = RuntimeType(ContentInsetAdjustmentBehavior.self, [
                "automatic": .automatic,
                "scrollableAxes": .scrollableAxes,
                "never": .never,
                "always": .always,
            ])
        }
        types["indicatorStyle"] = RuntimeType(UIScrollViewIndicatorStyle.self, [
            "default": .default,
            "black": .black,
            "white": .white,
        ])
        types["indexDisplayMode"] = RuntimeType(UIScrollViewIndexDisplayMode.self, [
            "automatic": .automatic,
            "alwaysHidden": .alwaysHidden,
        ])
        types["keyboardDismissMode"] = RuntimeType(UIScrollViewKeyboardDismissMode.self, [
            "none": .none,
            "onDrag": .onDrag,
            "interactive": .interactive,
        ])
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "contentInsetAdjustmentBehavior":
            if #available(iOS 11.0, *) {
                fallthrough
            }
            let key: String
            switch value as! ContentInsetAdjustmentBehavior {
            case .automatic:
                key = "automatic"
            case .scrollableAxes:
                key = "scrollableAxes"
            case .never:
                return // Do nothing
            case .always:
                key = "always"
            }
            throw SymbolError("Setting `contentInsetAdjustmentBehavior` to `\(key)` is not supported on iOS versions prior to 11. Set it to `never` for consistent behavior across iOS versions,", for: name)
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

