//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

// Internal struct used to store
// serialized layouts
struct Layout {
    var className: String
    var outlet: String?
    var expressions: [String: String]
    var children: [Layout]
    var xmlPath: String?
    var relativePath: String?
}
