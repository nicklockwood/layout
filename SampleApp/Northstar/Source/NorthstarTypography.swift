//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public extension UIFont {

    public static let heading0: UIFont = .systemFont(ofSize: CGFloat(50), weight: UIFontWeightHeavy)

    public static let heading1: UIFont = .systemFont(ofSize: CGFloat(28), weight: UIFontWeightHeavy)

    public static let heading2: UIFont = .systemFont(ofSize: CGFloat(20), weight: UIFontWeightMedium)

    public static let bodyBold: UIFont = .systemFont(ofSize: CGFloat(16), weight: UIFontWeightMedium)

    public static let body: UIFont = .systemFont(ofSize: CGFloat(16), weight: UIFontWeightRegular)

    public static let bodyAlt: UIFont = body

    public static let bodyHint: UIFont = body

    public static let bodyColor: UIFont = body

    public static let bodyWhite: UIFont = body

    public static let small: UIFont = .systemFont(ofSize: CGFloat(14), weight: UIFontWeightRegular)

    public static let smallColor: UIFont = small
}

public extension CGFloat {

    public static let lineHeightHeading0: CGFloat = 58

    public static let lineHeightHeading1: CGFloat = 36

    public static let lineHeightHeading2: CGFloat = 28

    public static let lineHeightBodyBold: CGFloat = 24

    public static let lineHeightBody: CGFloat = 24

    public static let lineHeightBodyAlt: CGFloat = lineHeightBody

    public static let lineHeightBodyHint: CGFloat = lineHeightBody

    public static let lineHeightBodyColor: CGFloat = lineHeightBody

    public static let lineHeightBodyWhite: CGFloat = lineHeightBody

    public static let lineHeightSmall: CGFloat = 20

    public static let lineHeightSmallColor: CGFloat = lineHeightSmall
}

public extension UIColor {

    public static let heading0: UIColor = .northstarPrimaryText

    public static let heading1: UIColor = .northstarPrimaryText

    public static let heading2: UIColor = .northstarPrimaryText

    public static let bodyBold: UIColor = .northstarPrimaryText

    public static let body: UIColor = .northstarPrimaryText

    public static let bodyAlt: UIColor = .northstarSecondaryText

    public static let bodyHint: UIColor = .northstarTertiaryText

    public static let bodyColor: UIColor = .northstarPrimary

    public static let bodyWhite: UIColor = .white

    public static let small: UIColor = .northstarSecondaryText

    public static let smallColor: UIColor = .northstarPrimary
}

public enum NorthstarTextStyleColor {

    case defaultColor
    case colored(UIColor)

    public func resolve(withDefault defaultColor: UIColor) -> UIColor {
        switch self {
        case .defaultColor:
            return defaultColor
        case let .colored(color):
            return color
        }
    }
}

public enum NorthstarTextStyle: RawRepresentable {
    case heading0(NorthstarTextStyleColor)
    case heading1(NorthstarTextStyleColor)
    case heading2(NorthstarTextStyleColor)
    case bodyBold(NorthstarTextStyleColor)
    case body(NorthstarTextStyleColor)
    case bodyAlt(NorthstarTextStyleColor)
    case bodyHint(NorthstarTextStyleColor)
    case bodyColor(NorthstarTextStyleColor)
    case bodyWhite(NorthstarTextStyleColor)
    case small(NorthstarTextStyleColor)
    case smallColor(NorthstarTextStyleColor)

    public var rawValue: String {
        switch self {
        case .heading0:
            return "heading0"
        case .heading1:
            return "heading1"
        case .heading2:
            return "heading2"
        case .bodyBold:
            return "bodyBold"
        case .body:
            return "body"
        case .bodyAlt:
            return "bodyAlt"
        case .bodyHint:
            return "bodyHint"
        case let .bodyColor(.colored(color)) where color === UIColor.northstarError:
            return "bodyError"
        case .bodyColor:
            return "bodyColor"
        case .bodyWhite:
            return "bodyWhite"
        case .small:
            return "small"
        case .smallColor:
            return "smallColor"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "heading0":
            self = .heading0(.defaultColor)
        case "heading1":
            self = .heading1(.defaultColor)
        case "heading2":
            self = .heading2(.defaultColor)
        case "bodyBold":
            self = .bodyBold(.defaultColor)
        case "body":
            self = .body(.defaultColor)
        case "bodyAlt":
            self = .bodyAlt(.defaultColor)
        case "bodyHint":
            self = .bodyHint(.defaultColor)
        case "bodyColor":
            self = .bodyColor(.defaultColor)
        case "bodyError":
            self = .bodyColor(.colored(.northstarError))
        case "bodyWhite":
            self = .bodyWhite(.defaultColor)
        case "small":
            self = .small(.defaultColor)
        case "smallColor":
            self = .smallColor(.defaultColor)
        default:
            return nil
        }
    }

    public var northstarTextAttributes: NorthstarTextAttributes {
        switch self {
        case let .heading0(color):
            return NorthstarTextAttributes(font: .heading0, lineHeight: .lineHeightHeading0, textColor: color.resolve(withDefault: .heading0))
        case let .heading1(color):
            return NorthstarTextAttributes(font: .heading1, lineHeight: .lineHeightHeading1, textColor: color.resolve(withDefault: .heading1))
        case let .heading2(color):
            return NorthstarTextAttributes(font: .heading2, lineHeight: .lineHeightHeading2, textColor: color.resolve(withDefault: .heading2))
        case let .bodyBold(color):
            return NorthstarTextAttributes(font: .bodyBold, lineHeight: .lineHeightBodyBold, textColor: color.resolve(withDefault: .bodyBold))
        case let .body(color):
            return NorthstarTextAttributes(font: .body, lineHeight: .lineHeightBody, textColor: color.resolve(withDefault: .body))
        case let .bodyAlt(color):
            return NorthstarTextAttributes(font: .bodyAlt, lineHeight: .lineHeightBodyAlt, textColor: color.resolve(withDefault: .bodyAlt))
        case let .bodyHint(color):
            return NorthstarTextAttributes(font: .bodyHint, lineHeight: .lineHeightBodyHint, textColor: color.resolve(withDefault: .bodyHint))
        case let .bodyColor(color):
            return NorthstarTextAttributes(font: .bodyColor, lineHeight: .lineHeightBodyColor, textColor: color.resolve(withDefault: .bodyColor))
        case let .bodyWhite(color):
            return NorthstarTextAttributes(font: .bodyWhite, lineHeight: .lineHeightBodyWhite, textColor: color.resolve(withDefault: .bodyWhite))
        case let .small(color):
            return NorthstarTextAttributes(font: .small, lineHeight: .lineHeightSmall, textColor: color.resolve(withDefault: .small))
        case let .smallColor(color):
            return NorthstarTextAttributes(font: .smallColor, lineHeight: .lineHeightSmallColor, textColor: color.resolve(withDefault: .smallColor))
        }
    }
}

public struct NorthstarTextAttributes {

    public var font: UIFont
    public var lineHeight: CGFloat
    public var textColor: UIColor
    public var lineBreakMode: NSLineBreakMode = .byWordWrapping
    public var textAlignment: NSTextAlignment = .left

    public init(font: UIFont, lineHeight: CGFloat, textColor: UIColor) {
        self.font = font
        self.lineHeight = lineHeight
        self.textColor = textColor
    }

    public var characterAttributes: [String: Any] {
        let style = NSMutableParagraphStyle()
        style.maximumLineHeight = lineHeight
        style.minimumLineHeight = lineHeight
        style.lineBreakMode = lineBreakMode
        style.alignment = textAlignment
        return [
            NSParagraphStyleAttributeName: style,
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor,
        ]
    }
}

extension NSAttributedString {
    public convenience init(string: String, northstarTextAttributes: NorthstarTextAttributes) {
        self.init(string: string, attributes: northstarTextAttributes.characterAttributes)
    }
}
