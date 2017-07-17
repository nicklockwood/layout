//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

public extension LayoutNode {

    static func with(xmlData: Data, relativeTo: String? = #file) throws -> LayoutNode {
        return try LayoutNode(
            layout: Layout(xmlData: xmlData, relativeTo: relativeTo)
        )
    }
}
