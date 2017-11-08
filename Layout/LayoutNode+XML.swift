//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

public extension LayoutNode {

    @available(*, deprecated, renamed: "init(xmlData:)")
    static func with(xmlData: Data, relativeTo: String? = #file) throws -> LayoutNode {
        return try LayoutNode(
            layout: Layout(xmlData: xmlData, relativeTo: relativeTo)
        )
    }

    convenience init(xmlData: Data, relativeTo: String? = #file) throws {
        try self.init(layout: Layout(xmlData: xmlData, relativeTo: relativeTo))
    }
}
