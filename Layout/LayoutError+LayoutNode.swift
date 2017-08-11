//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension LayoutError {
    init(_ message: String, for node: LayoutNode? = nil) {
        if let node = node {
            self = LayoutError(LayoutError.message(message), for: node)
        } else {
            self = .message(message)
        }
    }

    init(_ error: Error, for viewOrControllerClass: AnyClass) {
        if let error = error as? LayoutError, case .multipleMatches = error {
            // Should never be wrapped or it's hard to treat as special case
            self = error
            return
        }
        if case let LayoutError.generic(error, cls) = error, cls === viewOrControllerClass {
            self = .generic(error, cls)
            return
        }
        self = .generic(error, viewOrControllerClass)
    }

    init(_ error: Error, for node: LayoutNode?) {
        if let node = node {
            self.init(error, for: node._class)
        } else {
            self.init(error)
        }
    }

    static func wrap<T>(_ closure: () throws -> T, for node: LayoutNode) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: node)
        }
    }
}
