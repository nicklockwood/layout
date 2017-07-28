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
    var templatePath: String?
    var relativePath: String?

    func getClass() throws -> AnyClass {
        let classPrefix = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? ""
        guard let anyClass = NSClassFromString(className) ??
            NSClassFromString("\(classPrefix).\(className)") else {
            throw LayoutError.message("Unknown class `\(className)`")
        }
        return anyClass
    }
}
