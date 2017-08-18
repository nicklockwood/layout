//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Foundation

private func stringify(_ value: Any) throws -> String {
    switch try unwrap(value) {
    case let number as NSNumber:
        guard let int = Int64(exactly: Double(number)) else {
            return "\(number)"
        }
        return "\(int)"
    case let value as NSAttributedString:
        return value.string
    case let value:
        return "\(value)"
    }
}

private let ignoredSymbols: Set<Expression.Symbol> = [
    .variable("pi"),
    .variable("true"),
    .variable("false"),
    .variable("nil"),
]

struct LayoutExpression {
    let evaluate: () throws -> Any
    let symbols: Set<String>

    static let void = LayoutExpression(evaluate: { () }, symbols: ["_"])
    var isVoid: Bool { return symbols.first == "_" }

    init(evaluate: @escaping () throws -> Any, symbols: Set<String>) {
        self.symbols = symbols
        if symbols.isEmpty, let value = try? evaluate() {
            self.evaluate = { value }
        } else {
            self.evaluate = evaluate
        }
    }

    init(doubleExpression: String, for node: LayoutNode) {
        self.init(
            anyExpression: doubleExpression,
            type: RuntimeType(Double.self),
            for: node
        )
    }

    init(boolExpression: String, for node: LayoutNode) {
        self.init(
            anyExpression: boolExpression,
            type: RuntimeType(Bool.self),
            for: node
        )
    }

    private init(percentageExpression: String,
                 for prop: String, in node: LayoutNode,
                 symbols: [Expression.Symbol: Expression.Symbol.Evaluator] = [:]) {

        let prop = "parent.\(prop)"
        var symbols = symbols
        symbols[.postfix("%")] = { [unowned node] args in
            try node.doubleValue(forSymbol: prop) / 100 * args[0]
        }
        let expression = LayoutExpression(
            anyExpression: percentageExpression,
            type: RuntimeType(CGFloat.self),
            numericSymbols: symbols,
            for: node
        )
        self.init(
            evaluate: expression.evaluate,
            symbols: Set(expression.symbols.map { $0 == "%" ? prop : $0 })
        )
    }

    init(xExpression: String, for node: LayoutNode) {
        self.init(percentageExpression: xExpression, for: "width", in: node)
    }

    init(yExpression: String, for node: LayoutNode) {
        self.init(percentageExpression: yExpression, for: "height", in: node)
    }

    private init(sizeExpression: String, for prop: String, in node: LayoutNode) {
        let sizeProp = "inferredSize.\(prop)"
        let expression = LayoutExpression(
            percentageExpression: sizeExpression,
            for: prop, in: node,
            symbols: [.variable("auto"): { [unowned node] _ in
                try node.doubleValue(forSymbol: sizeProp)
            }]
        )
        self.init(
            evaluate: expression.evaluate,
            symbols: Set(expression.symbols.map { $0 == "auto" ? sizeProp : $0 })
        )
    }

    init(widthExpression: String, for node: LayoutNode) {
        self.init(sizeExpression: widthExpression, for: "width", in: node)
    }

    init(heightExpression: String, for node: LayoutNode) {
        self.init(sizeExpression: heightExpression, for: "height", in: node)
    }

    private init(contentSizeExpression: String, for prop: String, in node: LayoutNode) {
        let sizeProp = "inferredContentSize.\(prop)"
        let expression = LayoutExpression(
            percentageExpression: contentSizeExpression,
            for: prop, in: node,
            symbols: [.variable("auto"): { [unowned node] _ in
                try node.doubleValue(forSymbol: sizeProp)
            }]
        )
        self.init(
            evaluate: expression.evaluate,
            symbols: Set(expression.symbols.map { $0 == "auto" ? sizeProp : $0 })
        )
    }

    init(contentWidthExpression: String, for node: LayoutNode) {
        self.init(contentSizeExpression: contentWidthExpression, for: "width", in: node)
    }

    init(contentHeightExpression: String, for node: LayoutNode) {
        self.init(contentSizeExpression: contentHeightExpression, for: "height", in: node)
    }

    // symbols are assumed to be pure - i.e. they will always return the same value
    // numericSymbols are assumed to be impure - i.e. they won't always return the same value
    private init(anyExpression: String,
                 type: RuntimeType,
                 nullable: Bool = false,
                 symbols: [AnyExpression.Symbol: AnyExpression.SymbolEvaluator] = [:],
                 numericSymbols: [AnyExpression.Symbol: Expression.Symbol.Evaluator] = [:],
                 lookup: @escaping (String) -> Any? = { _ in nil },
                 for node: LayoutNode) {
        do {
            self.init(
                anyExpression: try parseExpression(anyExpression),
                type: type,
                nullable: nullable,
                symbols: symbols,
                numericSymbols: numericSymbols,
                lookup: lookup,
                for: node
            )
        } catch {
            self.init(
                evaluate: { throw error },
                symbols: []
            )
        }
    }

    // symbols are assumed to be pure - i.e. they will always return the same value
    // numericSymbols are assumed to be impure - i.e. they won't always return the same value
    private init(anyExpression parsedExpression: ParsedExpression,
                 type: RuntimeType,
                 nullable: Bool,
                 symbols: [AnyExpression.Symbol: AnyExpression.SymbolEvaluator] = [:],
                 numericSymbols: [AnyExpression.Symbol: Expression.Symbol.Evaluator] = [:],
                 lookup: @escaping (String) -> Any? = { _ in nil },
                 for node: LayoutNode) {

        var constants = [String: Any]()
        var symbols = symbols
        for symbol in parsedExpression.symbols where symbols[symbol] == nil &&
            numericSymbols[symbol] == nil && !ignoredSymbols.contains(symbol) {
            if case let .variable(name) = symbol {
                var key = name
                let chars = name.characters
                if chars.count >= 2, let first = chars.first, let last = chars.last,
                    last == first, first == "`" {
                    key = String(chars.dropFirst().dropLast())
                }
                if let value = node.value(forConstant: key) ?? lookup(key) {
                    constants[name] = value
                } else {
                    symbols[symbol] = { [unowned node] _ in
                        try node.value(forSymbol: key)
                    }
                }
            }
        }
        let evaluator: AnyExpression.Evaluator? = numericSymbols.isEmpty ? nil : { symbol, anyArgs in
            guard let fn = numericSymbols[symbol] else { return nil }
            var args = [Double]()
            for arg in anyArgs {
                if let doubleValue = arg as? Double {
                    args.append(doubleValue)
                } else if let cgFloatValue = arg as? CGFloat {
                    args.append(Double(cgFloatValue))
                } else if let numberValue = arg as? NSNumber {
                    args.append(Double(numberValue))
                } else {
                    return nil
                }
            }
            return try fn(args)
        }
        let expression = AnyExpression(
            parsedExpression,
            options: [.boolSymbols, .pureSymbols],
            constants: constants,
            symbols: symbols,
            evaluator: evaluator
        )
        self.init(
            evaluate: {
                let anyValue = try expression.evaluate()
                if nullable, optionalValue(of: anyValue) == nil {
                    return anyValue
                }
                guard let value = type.cast(anyValue) else {
                    let value = try unwrap(anyValue)
                    throw Expression.Error.message("\(type(of: value)) is not compatible with expected type \(type)")
                }
                return value
            },
            symbols: Set(expression.symbols.flatMap {
                switch $0 {
                case let .variable(string), let .postfix(string):
                    return string
                default:
                    return nil
                }
            })
        )
    }

    private init(colorExpression: String, type: RuntimeType, for node: LayoutNode) {
        self.init(
            anyExpression: colorExpression,
            type: type,
            symbols: [
                .function("rgb", arity: 3): { args in
                    guard let r = args[0] as? Double, let g = args[1] as? Double, let b = args[2] as? Double else {
                        throw Expression.Error.message("Type mismatch")
                    }
                    return UIColor(red: CGFloat(r / 255), green: CGFloat(g / 255), blue: CGFloat(b / 255), alpha: 1)
                },
                .function("rgba", arity: 4): { args in
                    guard let r = args[0] as? Double, let g = args[1] as? Double,
                        let b = args[2] as? Double, let a = args[3] as? Double else {
                        throw Expression.Error.message("Type mismatch")
                    }
                    return UIColor(red: CGFloat(r / 255), green: CGFloat(g / 255), blue: CGFloat(b / 255), alpha: CGFloat(a))
                },
            ],
            lookup: { string in
                if string.hasPrefix("#") {
                    var string = String(string.characters.dropFirst())
                    switch string.characters.count {
                    case 3:
                        string += "f"
                        fallthrough
                    case 4:
                        let chars = string.characters
                        let red = chars[chars.index(chars.startIndex, offsetBy: 0)]
                        let green = chars[chars.index(chars.startIndex, offsetBy: 1)]
                        let blue = chars[chars.index(chars.startIndex, offsetBy: 2)]
                        let alpha = chars[chars.index(chars.startIndex, offsetBy: 3)]
                        string = "\(red)\(red)\(green)\(green)\(blue)\(blue)\(alpha)\(alpha)"
                    case 6:
                        string += "ff"
                    case 8:
                        break
                    default:
                        return nil
                    }
                    if let rgba = Double("0x" + string).flatMap({ UInt32(exactly: $0) }) {
                        let red = CGFloat((rgba & 0xFF00_0000) >> 24) / 255
                        let green = CGFloat((rgba & 0x00FF_0000) >> 16) / 255
                        let blue = CGFloat((rgba & 0x0000_FF00) >> 8) / 255
                        let alpha = CGFloat((rgba & 0x0000_00FF) >> 0) / 255
                        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
                    }
                } else if UIColor.responds(to: Selector(string)) {
                    return UIColor.value(forKey: string)
                } else {
                    let key = string + "Color"
                    if UIColor.responds(to: Selector(key)) {
                        return UIColor.value(forKey: key)
                    }
                }
                return nil
            },
            for: node
        )
    }

    init(colorExpression: String, for node: LayoutNode) {
        self.init(colorExpression: colorExpression, type: RuntimeType(UIColor.self), for: node)
    }

    init(cgColorExpression: String, for node: LayoutNode) {
        self.init(colorExpression: cgColorExpression, type: RuntimeType(CGColor.self), for: node)
    }

    private init(interpolatedStringExpression expression: String, for node: LayoutNode) {
        enum ExpressionPart {
            case string(String)
            case expression(() throws -> Any)
        }

        do {
            var symbols = Set<String>()
            let parts: [ExpressionPart] = try parseStringExpression(expression).map { part in
                switch part {
                case let .expression(parsedExpression):
                    let expression = LayoutExpression(
                        anyExpression: parsedExpression,
                        type: RuntimeType(Any.self),
                        nullable: true,
                        for: node
                    )
                    symbols.formUnion(expression.symbols)
                    return .expression(expression.evaluate)
                case let .string(string):
                    return .string(string)
                }
            }
            self.init(
                evaluate: {
                    try parts.map { part -> Any in
                        switch part {
                        case let .expression(evaluate):
                            return try evaluate()
                        case let .string(string):
                            return string
                        }
                    }
                },
                symbols: symbols
            )
        } catch {
            self.init(
                evaluate: { throw error },
                symbols: []
            )
        }
    }

    init(stringExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(interpolatedStringExpression: stringExpression, for: node)
        self.init(
            evaluate: {
                let parts = try expression.evaluate() as! [Any]
                if parts.count == 1, isNil(parts[0]) {
                    return ""
                }
                return try parts.map({ try stringify($0) }).joined()
            },
            symbols: expression.symbols
        )
    }

    init(attributedStringExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(interpolatedStringExpression: attributedStringExpression, for: node)
        self.init(
            evaluate: {
                var substrings = [NSAttributedString]()
                var htmlString = ""
                for part in try expression.evaluate() as! [Any] {
                    switch part {
                    case let part as NSAttributedString:
                        htmlString += "$\(substrings.count)"
                        substrings.append(part)
                    default:
                        htmlString += try stringify(part)
                    }
                }
                let result = try NSMutableAttributedString(
                    data: htmlString.data(using: .utf8, allowLossyConversion: true) ?? Data(),
                    options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType],
                    documentAttributes: nil
                )
                let correctFont = try node.value(forSymbol: "font") as? UIFont ?? UIFont.systemFont(ofSize: 17)
                let range = NSMakeRange(0, result.string.utf16.count)
                result.enumerateAttributes(in: range, options: []) { attribs, range, _ in
                    var attribs = attribs
                    if let font = attribs[NSFontAttributeName] as? UIFont {
                        let traits = font.fontDescriptor.symbolicTraits
                        var descriptor = correctFont.fontDescriptor
                        descriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
                        attribs[NSFontAttributeName] = UIFont(descriptor: descriptor, size: correctFont.pointSize)
                        result.setAttributes(attribs, range: range)
                    }
                }
                if let color = try node.value(forSymbol: "textColor") as? UIColor {
                    result.addAttribute(NSForegroundColorAttributeName, value: color, range: range)
                }
                for (i, substring) in substrings.enumerated().reversed() {
                    let range = (result.string as NSString).range(of: "$\(i)")
                    if range.location != NSNotFound {
                        result.replaceCharacters(in: range, with: substring)
                    }
                }
                return result
            },
            symbols: Set(expression.symbols + ["font", "textColor"])
        )
    }

    // This is the actual default font size on iOS
    // which is not the same as reported by `UIFont.systemFontSize`
    static let defaultFontSize: CGFloat = 17

    // Needed because the Swift names don't match the rawValue constants
    static let fontTextStyles: [String: UIFontTextStyle] = [
        "title1": .title1,
        "title2": .title2,
        "title3": .title3,
        "headline": .headline,
        "subheadline": .subheadline,
        "body": .body,
        "callout": .callout,
        "footnote": .footnote,
        "caption1": .caption1,
        "caption2": .caption2,
    ]

    init(fontExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(interpolatedStringExpression: fontExpression, for: node)

        struct RelativeFontSize {
            let factor: CGFloat
        }

        // Parse a stringified font part
        func fontPart(for string: String) -> Any? {
            switch string {
            case "bold":
                return UIFontDescriptorSymbolicTraits.traitBold
            case "italic":
                return UIFontDescriptorSymbolicTraits.traitItalic
            case "condensed":
                return UIFontDescriptorSymbolicTraits.traitCondensed
            case "expanded":
                return UIFontDescriptorSymbolicTraits.traitExpanded
            case "monospace", "monospaced":
                return UIFontDescriptorSymbolicTraits.traitMonoSpace
            case "system":
                return UIFont.systemFont(ofSize: LayoutExpression.defaultFontSize)
            default:
                if let size = Double(string) {
                    return size
                }
                if string.hasSuffix("%"),
                    let size = Double(string.substring(to: string.index(before: string.endIndex))) {
                    return RelativeFontSize(factor: CGFloat(size / 100))
                }
                if let font = UIFont(name: string, size: LayoutExpression.defaultFontSize) {
                    return font
                }
                if let fontStyle = LayoutExpression.fontTextStyles[string] {
                    return fontStyle
                }
                if let familyName = UIFont.familyNames.first(where: {
                    $0.lowercased() == string
                }), let fontName = UIFont.fontNames(forFamilyName: familyName).first,
                    let font = UIFont(name: fontName, size: LayoutExpression.defaultFontSize) {
                    return font
                }
                return nil
            }
        }

        // Generate evaluator
        self.init(
            evaluate: {

                // Parse font parts
                var parts = [Any]()
                var string = ""
                func processString() throws {
                    if !string.isEmpty {
                        var characters = String.UnicodeScalarView.SubSequence(string.unicodeScalars)
                        var result = String.UnicodeScalarView()
                        var delimiter: UnicodeScalar?
                        var fontName: String?
                        while let char = characters.popFirst() {
                            switch char {
                            case "'", "\"":
                                if char == delimiter {
                                    if !result.isEmpty {
                                        let string = String(result)
                                        result.removeAll()
                                        guard let part = fontPart(for: string) else {
                                            throw Expression.Error.message("Invalid font specifier `\(string)`")
                                        }
                                        fontName = part is UIFont ? string : nil
                                        parts.append(part)
                                    }
                                    delimiter = nil
                                } else {
                                    delimiter = char
                                }
                            case " ":
                                if delimiter != nil {
                                    fallthrough
                                }
                                if !result.isEmpty {
                                    let string = String(result)
                                    result.removeAll()
                                    if let part = fontPart(for: string) {
                                        fontName = part is UIFont ? string : nil
                                        parts.append(part)
                                    } else if let prevName = fontName {
                                        // Might form a longer font name with the previous part
                                        fontName = "\(prevName) \(string)"
                                        if let part = fontPart(for: fontName!) {
                                            fontName = nil
                                            parts.removeLast()
                                            parts.append(part)
                                        }
                                    } else {
                                        fontName = string
                                    }
                                }
                            default:
                                result.append(char)
                            }
                        }
                        if !result.isEmpty {
                            let string = String(result)
                            guard let part = fontPart(for: string) else {
                                throw Expression.Error.message("Invalid font specifier `\(string)`")
                            }
                            parts.append(part)
                        }
                        string = ""
                    }
                }
                for part in try expression.evaluate() as! [Any] {
                    let part = try unwrap(part)
                    switch part {
                    case is UIFont,
                         is UIFontTextStyle,
                         is UIFontDescriptorSymbolicTraits,
                         is RelativeFontSize,
                         is NSNumber:
                        try processString()
                        parts.append(part)
                    case let part:
                        string += "\(part)"
                    }
                }
                try processString()

                // Build the font
                var font: UIFont!
                var fontSize: CGFloat!
                var traits = UIFontDescriptorSymbolicTraits()
                for part in parts {
                    switch part {
                    case let part as UIFont:
                        font = part
                    case let trait as UIFontDescriptorSymbolicTraits:
                        traits.insert(trait)
                    case let size as NSNumber:
                        fontSize = CGFloat(size)
                    case let size as RelativeFontSize:
                        fontSize = (fontSize ?? LayoutExpression.defaultFontSize) * size.factor
                    case let style as UIFontTextStyle:
                        let preferredFont = UIFont.preferredFont(forTextStyle: style)
                        fontSize = preferredFont.pointSize
                        font = font ?? preferredFont
                    default:
                        throw Expression.Error.message("Invalid font specifier `\(part)`")
                    }
                }
                fontSize = fontSize ?? font?.pointSize ?? LayoutExpression.defaultFontSize
                font = font ?? UIFont.systemFont(ofSize: fontSize)
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
                return UIFont(descriptor: descriptor, size: fontSize)
            },
            symbols: expression.symbols
        )
    }

    init(imageExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(interpolatedStringExpression: imageExpression, for: node)
        self.init(
            evaluate: {
                let parts = try expression.evaluate() as! [Any]
                if parts.count == 1, isNil(parts[0]) {
                    // Explicitly allow empty images
                    return UIImage()
                }
                var image: UIImage?
                var string = ""
                for part in parts {
                    switch part {
                    case let part as UIImage:
                        image = part
                    default:
                        let stringified = try stringify(part)
                        if stringified.hasPrefix("<CGImage") {
                            return UIImage(cgImage: part as! CGImage)
                        }
                        string += stringified
                    }
                }
                string = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if let image = image {
                    if !string.isEmpty {
                        throw Expression.Error.message("Invalid image specifier `\(string)`")
                    }
                    return image
                } else {
                    let parts = string.components(separatedBy: ":")
                    var bundle = Bundle.main
                    if parts.count == 2 {
                        let identifier = parts.first!
                        string = parts.last!
                        guard let _bundle = Bundle(identifier: identifier) else {
                            throw Expression.Error.message("Could not locate bundle with identifier \(identifier)")
                        }
                        bundle = _bundle
                    }
                    if let image = UIImage(named: parts.last!, in: bundle, compatibleWith: nil) {
                        return image
                    }
                    throw Expression.Error.message("Invalid image name \(string)")
                }
            },
            symbols: expression.symbols
        )
    }

    init(cgImageExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(imageExpression: cgImageExpression, for: node)
        self.init(
            evaluate: { (try expression.evaluate() as! UIImage).cgImage as Any },
            symbols: expression.symbols
        )
    }

    init(enumExpression: String, type: RuntimeType, for node: LayoutNode) {
        guard case let .enum(_, values) = type.type else { preconditionFailure() }
        self.init(
            anyExpression: enumExpression,
            type: type,
            symbols: [:],
            lookup: { name in values[name] },
            for: node
        )
    }

    init(selectorExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(stringExpression: selectorExpression, for: node)
        self.init(
            evaluate: { Selector(try expression.evaluate() as! String) },
            symbols: expression.symbols
        )
    }

    init(expression: String, type: RuntimeType, for node: LayoutNode) {
        switch type.type {
        case let .any(subtype):
            switch subtype {
            case is String.Type,
                 is NSString.Type:
                self.init(stringExpression: expression, for: node)
            case is Selector.Type:
                self.init(selectorExpression: expression, for: node)
            case is NSAttributedString.Type:
                self.init(attributedStringExpression: expression, for: node)
            case is UIColor.Type:
                self.init(colorExpression: expression, for: node)
            case is UIImage.Type:
                self.init(imageExpression: expression, for: node)
            case is UIFont.Type:
                self.init(fontExpression: expression, for: node)
            default:
                let expression = LayoutExpression(anyExpression: expression, type: type, for: node)
                self.init(
                    evaluate: { try unwrap(expression.evaluate()) }, // Handle nil
                    symbols: expression.symbols
                )
            }
        case .struct:
            let expression = LayoutExpression(anyExpression: expression, type: type, for: node)
            self.init(
                evaluate: { try unwrap(expression.evaluate()) }, // Handle nil
                symbols: expression.symbols
            )
        case .enum:
            self.init(enumExpression: expression, type: type, for: node)
        case .pointer("{CGColor=}"):
            self.init(cgColorExpression: expression, for: node)
        case .pointer("{CGImage=}"):
            self.init(cgImageExpression: expression, for: node)
        case .pointer, .protocol:
            self.init(anyExpression: expression, type: type, nullable: true, for: node)
        }
    }
}
