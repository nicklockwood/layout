//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

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

// Get a class by name, adding project prefix if needed
func classFromString(_ name: String) -> AnyClass? {
    return NSClassFromString(name) ?? NSClassFromString("\(classPrefix).\(name)")
}

// Get the name of a class, without project prefix
func nameOfClass(_ name: AnyClass) -> String {
    let name = NSStringFromClass(name)
    let prefix = "\(classPrefix)."
    if name.hasPrefix(prefix) {
        return String(name[prefix.endIndex...])
    }
    return name
}

// Get a protocol by name
func protocolFromString(_ name: String) -> Protocol? {
    return NSProtocolFromString(name) ?? NSProtocolFromString("\(classPrefix).\(name)")
}

// Internal API for converting a path to a full URL
func urlFromString(_ path: String, relativeTo baseURL: URL? = nil) -> URL {
    if path.hasPrefix("~") {
        let path = path.removingPercentEncoding ?? path
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    } else if let url = URL(string: path, relativeTo: baseURL), url.scheme != nil {
        return url
    }

    // Check if url has a scheme
    if baseURL != nil || path.contains(":") {
        let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        if let url = URL(string: path, relativeTo: baseURL) {
            return url
        }
    }

    // Assume local path
    if (path as NSString).isAbsolutePath {
        return URL(fileURLWithPath: path.removingPercentEncoding ?? path)
    } else {
        return Bundle.main.resourceURL!.appendingPathComponent(path)
    }
}

// Internal API for overriding built-in methods
func replace(_ sela: Selector, of cls: AnyClass, with selb: Selector) {
    let swizzledMethod = class_getInstanceMethod(cls, selb)!
    let originalMethod = class_getInstanceMethod(cls, sela)!
    let inheritedImplementation = class_getInstanceMethod(class_getSuperclass(cls), sela)
        .map(method_getImplementation)
    if method_getImplementation(originalMethod) == inheritedImplementation {
        let types = method_getTypeEncoding(originalMethod)
        class_addMethod(cls, sela, method_getImplementation(swizzledMethod), types)
        return
    }
    method_exchangeImplementations(originalMethod, swizzledMethod)
}

func imp(of sela: Selector, of cls: AnyClass, matches selb: Selector) -> Bool {
    let impa = class_getInstanceMethod(cls, sela).map(method_getImplementation)
    let impb = class_getInstanceMethod(cls, selb).map(method_getImplementation)
    return impa == impb
}

// MARK: Approximate equality

private let precision: CGFloat = 0.001

extension CGPoint {
    func isNearlyEqual(to other: CGPoint) -> Bool {
        return abs(x - other.x) <= precision && abs(y - other.y) <= precision
    }
}

extension CGSize {
    func isNearlyEqual(to other: CGSize) -> Bool {
        return abs(width - other.width) <= precision && abs(height - other.height) <= precision
    }
}

extension CGRect {
    func isNearlyEqual(to other: CGRect) -> Bool {
        return size.isNearlyEqual(to: other.size) && origin.isNearlyEqual(to: other.origin)
    }
}

extension UIEdgeInsets {
    func isNearlyEqual(to other: UIEdgeInsets) -> Bool {
        return
            abs(left - other.left) <= precision &&
            abs(right - other.right) <= precision &&
            abs(top - other.top) <= precision &&
            abs(bottom - other.bottom) <= precision
    }
}

// MARK: Backwards compatibility

struct IntOptionSet: OptionSet {
    let rawValue: Int
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

struct UIntOptionSet: OptionSet {
    let rawValue: UInt
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}
