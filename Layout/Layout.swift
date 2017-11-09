//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

// Internal struct used to store
// serialized layouts
struct Layout {
    var className: String
    var id: String?
    var expressions: [String: String]
    var parameters: [String: RuntimeType]
    var macros: [String: String]
    var children: [Layout]
    var body: String?
    var xmlPath: String?
    var templatePath: String?
    var relativePath: String?
    var rootURL: URL?

    func getClass() throws -> AnyClass {
        guard let cls: AnyClass = classFromString(className) else {
            throw LayoutError.message("Unknown class \(className)")
        }
        return cls
    }
}
