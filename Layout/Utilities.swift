//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

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

// Convert any object to a string
func stringify(_ value: Any) throws -> String {
    switch try unwrap(value) {
    case let bool as Bool:
        return bool ? "true" : "false"
    case let number as NSNumber:
        if let int = Int64(exactly: number) {
            return "\(int)"
        }
        if let uint = UInt64(exactly: number) {
            return "\(uint)"
        }
        return "\(number)"
    case let value as NSAttributedString:
        return value.string
    case let value:
        return "\(value)"
    }
}

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

// Get a protocol by name
func protocolFromString(_ name: String) -> Protocol? {
    return NSProtocolFromString(name) ?? NSProtocolFromString("\(classPrefix).\(name)")
}

// Internal API for converting a path to a full URL
func urlFromString(_ path: String) -> URL {
    if let url = URL(string: path), url.scheme != nil {
        return url
    }

    // Check for scheme
    if path.contains(":") {
        let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        if let url = URL(string: path) {
            return url
        }
    }

    // Assume local path
    let path = path.removingPercentEncoding ?? path
    if path.hasPrefix("~") {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    } else if (path as NSString).isAbsolutePath {
        return URL(fileURLWithPath: path)
    } else {
        return Bundle.main.resourceURL!.appendingPathComponent(path)
    }
}

private let precision: CGFloat = 0.001

extension CGSize {
    func isNearlyEqual(to other: CGSize?) -> Bool {
        guard let other = other else { return false }
        return abs(width - other.width) <= precision && abs(height - other.height) <= precision
    }
}

extension UIEdgeInsets {
    func isNearlyEqual(to other: UIEdgeInsets?) -> Bool {
        guard let other = other else { return false }
        return
            abs(left - other.left) <= precision &&
            abs(right - other.right) <= precision &&
            abs(top - other.top) <= precision &&
            abs(bottom - other.bottom) <= precision
    }
}

#if swift(>=3.2)
#else

    // Swift 3.2 compatibility helpers

    struct NSAttributedStringKey {}

#endif

#if swift(>=4)
#else

    // Swift 4 compatibility helpers

    extension NSAttributedString {
        struct DocumentType {
            static let html = NSHTMLTextDocumentType
        }

        struct DocumentReadingOptionKey {
            static let documentType = NSDocumentTypeDocumentAttribute
            static let characterEncoding = NSCharacterEncodingDocumentAttribute
        }
    }

    extension NSAttributedStringKey {
        static let foregroundColor = NSForegroundColorAttributeName
        static let font = NSFontAttributeName
        static let paragraphStyle = NSParagraphStyleAttributeName
    }

    extension UIFont {
        typealias Weight = UIFontWeight
    }

    extension UIFont.Weight {
        static let ultraLight = UIFontWeightUltraLight
        static let thin = UIFontWeightThin
        static let light = UIFontWeightLight
        static let regular = UIFontWeightRegular
        static let medium = UIFontWeightMedium
        static let semibold = UIFontWeightSemibold
        static let bold = UIFontWeightBold
        static let heavy = UIFontWeightHeavy
        static let black = UIFontWeightBlack
    }

    extension UIFontDescriptor {
        struct AttributeName {
            static let traits = UIFontDescriptorTraitsAttribute
        }

        typealias TraitKey = String
    }

    extension UIFontDescriptor.TraitKey {
        static let weight = UIFontWeightTrait
    }

    extension UILayoutPriority {
        var rawValue: Float { return self }
        init(rawValue: Float) { self = rawValue }

        static let required = UILayoutPriorityRequired
    }

    extension Int64 {
        init?(exactly number: NSNumber) {
            self.init(exactly: Double(number))
        }
    }

    extension Double {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension CGFloat {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension Float {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension Int {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension UInt {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension Bool {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

#endif
