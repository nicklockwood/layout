//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// Optional delegate protocol to be implemented by a LayoutNode's owner
@objc protocol LayoutDelegate {

    /// Notify that an error occured in the node tree
    @objc optional func layoutNode(_ layoutNode: LayoutNode, didDetectError error: Error)

    /// A variable or constant value inherited from delegate
    @objc optional func value(forParameterOrVariableOrConstant name: String) -> Any?
}
