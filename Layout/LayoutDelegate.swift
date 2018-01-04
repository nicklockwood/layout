//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// Optional delegate protocol to be implemented by a LayoutNode's owner
@objc protocol LayoutDelegate {

    /// A variable or constant value inherited from delegate
    @objc optional func value(forParameterOrVariableOrConstant name: String) -> Any?
}
