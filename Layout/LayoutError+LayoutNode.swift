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
        switch error {
        case let LayoutError.generic(error, cls) where cls === viewOrControllerClass:
            self = .generic(error, cls)
        default:
            self = .generic(error, viewOrControllerClass)
        }
    }

    init(_ error: Error, for node: LayoutNode? = nil) {
        if let error = error as? LayoutError, case .multipleMatches = error {
            // Should never be wrapped or it's hard to treat as special case
            self = error
            return
        }
        guard let node = node else {
            switch error {
            case let LayoutError.generic(error, viewClass):
                self = .generic(error, viewClass)
            default:
                self = .generic(error, nil)
            }
            return
        }
        self = LayoutError(error, for: node.viewController.map {
            $0.classForCoder
        } ?? node.viewClass)
    }

    init?(_ error: Error?) {
        guard let error = error else {
            return nil
        }
        self.init(error)
    }

    static func wrap<T>(_ closure: () throws -> T, for node: LayoutNode) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: node)
        }
    }
}
