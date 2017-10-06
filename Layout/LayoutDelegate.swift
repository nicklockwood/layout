//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// Optional delegate protocol to be implemented by a LayoutNode's owner
@objc protocol LayoutDelegate {

    /// Notify that an error occured in the node tree
    @objc optional func layoutNode(_ layoutNode: LayoutNode, didDetectError error: Error)

    /// Fetch a localized string constant for a given key.
    /// These strings are assumed to be constant for the duration of the layout tree's lifecycle
    @objc optional func layoutNode(_ layoutNode: LayoutNode, localizedStringForKey key: String) -> String?

    /// A variable or constant value inherited from delegate
    @objc optional func value(forParameterOrVariableOrConstant name: String) -> Any?
}
