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

// Get a class by name
func classFromString(_ name: String) -> AnyClass? {
    return NSClassFromString(name) ?? NSClassFromString("\(classPrefix).\(name)")
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
        }
    }

    extension NSAttributedStringKey {
        static let foregroundColor = NSForegroundColorAttributeName
        static let font = NSFontAttributeName
        static let paragraphStyle = NSParagraphStyleAttributeName
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
