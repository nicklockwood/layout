//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension LayoutError {
    init(_ message: String, for node: LayoutNode?) {
        self.init(LayoutError.message(message), for: node)
    }

    init(_ error: Error, for node: LayoutNode?) {
        let rootURL = node?.rootURL != node?.parent?.rootURL ? node?.rootURL : nil
        self.init(error, in: (node?._class).map(nameOfClass), in: rootURL)
    }

    static func wrap<T>(_ closure: () throws -> T, for node: LayoutNode) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: node)
        }
    }
}
