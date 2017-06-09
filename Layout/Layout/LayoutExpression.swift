//
//  NodeExpression.swift
//  TableTest
//
//  Created by Nick Lockwood on 06/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit
import Foundation
import Expression

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
]

private enum ParsedExpressionPart {
    case string(String)
    case expression(ParsedExpression)
}

private var expressionCache = [String: [ParsedExpressionPart]]()
private var stringExpressionCache = [String: [ParsedExpressionPart]]()
private func parseExpression(_ expression: String, isString: Bool) -> [ParsedExpressionPart] {
    assert(Thread.isMainThread)
    if let parts = (isString ? stringExpressionCache : expressionCache)[expression] {
        return parts
    }
    var parts = [ParsedExpressionPart]()
    var range = expression.startIndex ..< expression.endIndex
    while let subrange = expression.range(of: "\\{[^}]*\\}", options: .regularExpression, range: range) {
        let string = expression.substring(with: range.lowerBound ..< subrange.lowerBound)
        if !string.isEmpty {
            parts.append(.string(string))
        }
        let expressionString = String(expression.characters[subrange].dropFirst().dropLast())
        let parsedExpression = Expression.parse(expressionString, usingCache: false)
        parts.append(.expression(parsedExpression))
        range = subrange.upperBound ..< range.upperBound
    }
    if !range.isEmpty {
        parts.append(.string(expression.substring(with: range)))
    }
    if isString {
        stringExpressionCache[expression] = parts
        return parts
    }
    if parts.count == 1, case let .string(string) = parts[0] {
        parts[0] = .expression(Expression.parse(string, usingCache: false))
    }
    expressionCache[expression] = parts
    return parts
}

struct LayoutExpression {
    let evaluate: () throws -> Any
    let symbols: Set<String>

    static let void = LayoutExpression(evaluate: { () }, symbols: ["_"])
    var isVoid: Bool { return symbols.first == "_" }

    init(evaluate: @escaping () throws -> Any,  symbols: Set<String>) {
        self.symbols = symbols
        if symbols.isEmpty, let value = try? evaluate() {
            self.evaluate = { value }
        } else {
            self.evaluate = evaluate
        }
    }

    init(malformedExpression: String) {
        symbols = []
        evaluate = {
            throw Expression.Error.message("Malformed expression `\(malformedExpression)`")
        }
    }

    // Symbols are assumed to be impure - i.e. they won't always return the same value
    private init(numberExpression: String,
                 symbols: [Expression.Symbol: Expression.Symbol.Evaluator],
                 for node: LayoutNode)
    {
        self.init(
            anyExpression: numberExpression,
            type: RuntimeType(Double.self),
            symbols: [:],
            numericSymbols: symbols,
            for: node
        )
    }

    init(numberExpression: String, for node: LayoutNode) {
        self.init(numberExpression: numberExpression, symbols: [:], for: node)
    }

    private init(percentageExpression: String,
                 for prop: String, in node: LayoutNode,
                 symbols: [Expression.Symbol: Expression.Symbol.Evaluator] = [:])
    {
        let prop = "parent.\(prop)"
        var symbols = symbols
        symbols[.postfix("%")] = { [unowned node] args in
            try node.doubleValue(forSymbol: prop) / 100 * args[0]
        }
        let expression = LayoutExpression(
            numberExpression: percentageExpression,
            symbols: symbols,
            for: node
        )
        self.init(
            evaluate: { try expression.evaluate() },
            symbols: Set(expression.symbols.map { $0 == "%" ? prop : $0 })
        )
    }

    init(xExpression: String, for node: LayoutNode) {
        self.init(percentageExpression: xExpression, for: "width", in: node)
    }

    init(yExpression: String, for node: LayoutNode) {
        self.init(percentageExpression: yExpression, for: "height", in: node)
    }

    init(widthExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(
            percentageExpression: widthExpression,
            for: "width", in: node,
            symbols: [.variable("auto"): { [unowned node] _ in
                Double(node.contentSize.width)
            }]
        )
        self.init(
            evaluate: { try expression.evaluate() },
            symbols: Set(expression.symbols.map { $0 == "auto" ? "contentSize.width" : $0 })
        )
    }

    init(heightExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(
            percentageExpression: heightExpression,
            for: "height", in: node,
            symbols: [.variable("auto"): { [unowned node] _ in
                Double(node.contentSize.height)
            }]
        )
        self.init(
            evaluate: { try expression.evaluate() },
            symbols: Set(expression.symbols.map { $0 == "auto" ? "contentSize.height" : $0 })
        )
    }

    init(boolExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(numberExpression: boolExpression, for: node)
        self.init(
            evaluate: { try expression.evaluate() as! Double == 0 ? false : true },
            symbols: expression.symbols
        )
    }

    // symbols are assumed to be pure - i.e. they will always return the same value
    // numericSymbols are assumed to be impure - i.e. they won't always return the same value
    private init(anyExpression: String,
                 type: RuntimeType,
                 symbols: [AnyExpression.Symbol: AnyExpression.SymbolEvaluator],
                 numericSymbols: [AnyExpression.Symbol: Expression.Symbol.Evaluator] = [:],
                 lookup: @escaping (String) -> Any? = { _ in nil },
                 for node: LayoutNode)
    {
        let parts = parseExpression(anyExpression, isString: false)
        guard parts.count == 1, case let .expression(parsedExpression) = parts[0] else {
            self.init(malformedExpression: anyExpression)
            return
        }
        self.init(
            anyExpression: parsedExpression,
            type: type,
            symbols: symbols,
            numericSymbols: numericSymbols,
            lookup: lookup,
            for: node
        )
    }

    // symbols are assumed to be pure - i.e. they will always return the same value
    // numericSymbols are assumed to be impure - i.e. they won't always return the same value
    private init(anyExpression parsedExpression: ParsedExpression,
                 type: RuntimeType,
                 symbols: [AnyExpression.Symbol: AnyExpression.SymbolEvaluator] = [:],
                 numericSymbols: [AnyExpression.Symbol: Expression.Symbol.Evaluator] = [:],
                 lookup: @escaping (String) -> Any? = { _ in nil },
                 for node: LayoutNode)
    {
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
                if let value = lookup(key) ?? node.value(forConstant: key) {
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
                guard let value = type.cast(anyValue) else {
                    try _ = unwrap(anyValue)
                    throw Expression.Error.message("Type mismatch")
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

    init(anyExpression: String, type: RuntimeType, for node: LayoutNode) {
        self.init(anyExpression: anyExpression, type: type, symbols: [:], for: node)
    }

    init(colorExpression: String, for node: LayoutNode) {
        self.init(
            anyExpression: colorExpression,
            type: RuntimeType(UIColor.self),
            symbols: [
                .function("rgb", arity: 3): { args in
                    guard let r = args[0] as? Double, let g = args[1] as? Double, let b = args[2] as? Double else {
                        throw Expression.Error.message("Type mismatch")
                    }
                    return UIColor(red: CGFloat(r/255), green: CGFloat(g/255), blue: CGFloat(b/255), alpha: 1)
                },
                .function("rgba", arity: 4): { args in
                    guard let r = args[0] as? Double, let g = args[1] as? Double,
                        let b = args[2] as? Double, let a = args[3] as? Double else {
                            throw Expression.Error.message("Type mismatch")
                    }
                    return UIColor(red: CGFloat(r/255), green: CGFloat(g/255), blue: CGFloat(b/255), alpha: CGFloat(a))
                }
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
                        let red = CGFloat((rgba & 0xFF000000) >> 24) / 255
                        let green = CGFloat((rgba & 0x00FF0000) >> 16) / 255
                        let blue = CGFloat((rgba & 0x0000FF00) >> 8) / 255
                        let alpha = CGFloat((rgba & 0x000000FF) >> 0) / 255
                        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
                    }
                }
                return nil
            },
            for: node
        )
    }

    init(cgColorExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression.init(colorExpression: cgColorExpression, for: node)
        self.init(evaluate: { try (expression.evaluate() as! UIColor).cgColor }, symbols: expression.symbols)
    }

    private init(interpolatedStringExpression expression: String, for node: LayoutNode) {
        enum ExpressionPart {
            case string(String)
            case expression(() throws -> Any)
        }

        var symbols = Set<String>()
        let parts: [ExpressionPart] = parseExpression(expression, isString: true).map { part in
            switch part {
            case let .expression(parsedExpression):
                let expression = LayoutExpression(
                    anyExpression: parsedExpression,
                    type: RuntimeType(Any.self),
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
                return try parts.map { part -> Any in
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
        let symbols = expression.symbols
        // TODO: find out why these break stuff
//        symbols.insert("font")
//        symbols.insert("textColor")
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
                result.enumerateAttributes(in: range, options: []) { attribs, range, stop in
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
            symbols: symbols
        )
    }

    // This is the actual default font size on iOS
    // which is not the same as reported by `UIFont.systemFontSize`
    static let defaultFontSize: CGFloat = 17

    init(fontExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(interpolatedStringExpression: fontExpression, for: node)
        self.init(
            evaluate: {
                var font = UIFont.systemFont(ofSize: LayoutExpression.defaultFontSize)
                var traits = font.fontDescriptor.symbolicTraits
                for part in try expression.evaluate() as! [Any] {
                    switch try unwrap(part) {
                    case let part as UIFont:
                        font = part
                    default:
                        // Split into space-delimited parts
                        // TODO: can we support font names containing spaces without quotes?
                        var parts = "\(part)".lowercased().components(separatedBy: " ")
                        // Merge and un-escape quoted parts
                        // TODO: can this be done as a pre-processing step rather than after evaluation?
                        var stringEnd: Int?
                        for i in parts.indices.reversed() {
                            let part = parts[i]
                            for c in ["\"", "'"] {
                                if part.hasSuffix(c) {
                                    stringEnd = i
                                }
                                if part.hasPrefix(c), let end = stringEnd {
                                    var result = ""
                                    for part in parts[i ... end] {
                                        result += part
                                    }
                                    result = result.substring(with:
                                        result.index(after: result.startIndex) ..< result.index(before: result.endIndex)
                                    )
                                    parts[i ... end] = [result]
                                    stringEnd = nil
                                    break
                                }
                            }
                        }
                        // Build font
                        for part in parts where !part.isEmpty {
                            switch part {
                            case "bold":
                                traits.insert(.traitBold)
                            case "italic":
                                traits.insert(.traitItalic)
                            case "condensed":
                                traits.insert(.traitCondensed)
                            case "expanded":
                                traits.insert(.traitExpanded)
                            case "monospace", "monospaced":
                                traits.insert(.traitMonoSpace)
                            case "system":
                                font = UIFont.systemFont(ofSize: font.pointSize)
                            default:
                                if let size = Double(part) {
                                    font = font.withSize(CGFloat(size))
                                    break
                                }
                                if let newFont = UIFont(name: part, size: font.pointSize) {
                                    font = newFont
                                    break
                                }
                                if let familyName = UIFont.familyNames.first(where: {
                                    $0.lowercased() == part
                                }), let fontName = UIFont.fontNames(forFamilyName: familyName).first,
                                    let newFont = UIFont(name: fontName, size: font.pointSize) {
                                    font = newFont
                                }
                                throw Expression.Error.message("Invalid font specifier `\(part)`")
                            }
                        }
                    }
                }
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
                return UIFont(descriptor: descriptor, size: font.pointSize)
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
                        string += try stringify(part)
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
                            throw Expression.Error.message("Could not locate bundle with identifier `\(identifier)`")
                        }
                        bundle = _bundle
                    }
                    if let image = UIImage(named: parts.last!, in: bundle, compatibleWith: nil) {
                        return image
                    }
                    throw Expression.Error.message("Invalid image name `\(string)`")
                }
            },
            symbols: expression.symbols
        )
    }

    init(enumExpression: String, type: RuntimeType, for node: LayoutNode) {
        guard case let .enum(_, values, _) = type.type else { preconditionFailure() }
        self.init(
            anyExpression: enumExpression,
            type: type,
            symbols: [:],
            lookup: { name in values[name] },
            for: node
        )
    }

    init(expression: String, ofType type: RuntimeType, for node: LayoutNode) {
        switch type.type {
        case let .any(subtype):
            switch subtype {
            case _ where "\(subtype)" == "\(CGColor.self)":
                // Workaround for odd behavior in type matching
                self.init(cgColorExpression: expression, for: node)
            case is CGFloat.Type,
                 is Double.Type,
                 is Float.Type,
                 is Int.Type,
                 is NSNumber.Type:
                self.init(numberExpression: expression, for: node)
            case is Bool.Type:
                self.init(boolExpression: expression, for: node)
            case is String.Type,
                 is NSString.Type:
                self.init(stringExpression: expression, for: node)
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
        case .enum:
            self.init(enumExpression: expression, type: type, for: node)
        case .protocol:
            self.init(anyExpression: expression, type: type, for: node)
        }
    }
}
