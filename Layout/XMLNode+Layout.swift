//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension XMLNode {
    var isLayout: Bool {
        switch self {
        case let .node(name, attributes, children):
            guard let firstChar = name.characters.first.map({ String($0) }),
                firstChar.uppercased() == firstChar else {
                    return false
            }
            for key in attributes.keys {
                if ["top", "left", "bottom", "right", "width", "height", "backgroundColor"].contains(key) {
                    return true
                }
                if key.hasPrefix("layer.") {
                    return true
                }
            }
            return children.isLayout
        default:
            return false
        }
    }

    public var isParameter: Bool {
        guard case .node("param", _, _) = self else {
            return false
        }
        return true
    }

    public var parameters: [String: String] {
        var params = [String: String]()
        for child in children where child.isParameter {
            let attributes = child.attributes
            if let name = attributes["name"], let type = attributes["type"] {
                params[name] = type
            }
        }
        return params
    }
}

extension Collection where Iterator.Element == XMLNode {
    var isLayout: Bool {
        for node in self {
            if node.isLayout {
                return true
            }
        }
        return false
    }
}
