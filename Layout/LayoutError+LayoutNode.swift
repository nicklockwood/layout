//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension LayoutError {
    init(_ message: String, for node: LayoutNode?) {
        self.init(message, for: node?._class)
    }

    init(_ error: Error, for node: LayoutNode?) {
        self.init(error, for: node?._class)
    }

    static func wrap<T>(_ closure: () throws -> T, for node: LayoutNode) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: node)
        }
    }
}
