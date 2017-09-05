//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

// Flatten an array of dictionaries
func merge(_ dictionaries: [[String: Any]]) -> [String: Any] {
    var result = [String: Any]()
    for dict in dictionaries {
        for (key, value) in dict {
            result[key] = value
        }
    }
    return result
}

private let classPrefix = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "")
    .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)

// Get a class by name
func classFromString(_ name: String) -> AnyClass? {
    return NSClassFromString(name) ?? NSClassFromString("\(classPrefix).\(name)")
}

private let precision: CGFloat = 0.001

extension CGSize {

    func isNearlyEqual(to other: CGSize?) -> Bool {
        guard let other = other else { return false }
        return (fabs(width - other.width) <= precision) && (fabs(height - other.height) <= precision)
    }
}
