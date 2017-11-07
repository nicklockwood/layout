//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// Protocol for views or controllers that are backed by a LayoutNode
/// Exposes the node reference so that the view can update itself
public protocol LayoutBacked: class {
    weak var layoutNode: LayoutNode? { get }
}

extension LayoutBacked {
    public weak var layoutNode: LayoutNode? {
        return objc_getAssociatedObject(self, &layoutNodeKey) as? LayoutNode
    }

    internal func setLayoutNode(_ layoutNode: LayoutNode?) {
        objc_setAssociatedObject(self, &layoutNodeKey, layoutNode, .OBJC_ASSOCIATION_ASSIGN)
    }
}

private var layoutNodeKey = 0
