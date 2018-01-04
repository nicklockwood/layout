//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

open class LayoutViewController: UIViewController, LayoutLoading {
    /// Called immediately after the layoutNode is set. Will not be called
    /// in the event of an error, or if layoutNode is set to nil
    open func layoutDidLoad(_: LayoutNode) {
        // Mimic old behaviour if not overriden
        layoutDidLoad()
    }

    /// Called immediately after the layoutNode is set. Will not be called
    /// in the event of an error, or if layoutNode is set to nil
    @available(*, deprecated, message: "Use layoutDidLoad(_ layoutNode:) instead")
    open func layoutDidLoad() {
        // Override in subclass
    }
}
