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

private let commonSymbols: [Expression.Symbol: Expression.Symbol.Evaluator] = {
    var symbols: [Expression.Symbol: ([Double]) -> Double] = [:]

    // boolean constants
    symbols[.constant("true")] = { _ in 1 }
    symbols[.constant("false")] = { _ in 0 }

    // boolean infix operators
    symbols[.infix("==")] = { (args: [Double]) -> Double in args[0] == args[1] ? 1 : 0 }
    symbols[.infix("!=")] = { (args: [Double]) -> Double in args[0] != args[1] ? 1 : 0 }
    symbols[.infix(">")] = { (args: [Double]) -> Double in args[0] > args[1] ? 1 : 0 }
    symbols[.infix(">=")] = { (args: [Double]) -> Double in args[0] >= args[1] ? 1 : 0 }
    symbols[.infix("<")] = { (args: [Double]) -> Double in args[0] < args[1] ? 1 : 0 }
    symbols[.infix("<=")] = { (args: [Double]) -> Double in args[0] <= args[1] ? 1 : 0 }
    symbols[.infix("&&")] = { (args: [Double]) -> Double in args[0] != 0 && args[1] != 0 ? 1 : 0 }
    symbols[.infix("||")] = { (args: [Double]) -> Double in args[0] != 0 || args[1] != 0 ? 1 : 0 }

    // boolean prefix operators
    symbols[.prefix("!")] = { (args: [Double]) -> Double in args[0] == 0 ? 1 : 0 }

    // ternary operator
    symbols[.infix("?:")] = { (args: [Double]) -> Double in
        if args.count == 3 {
            return args[0] != 0 ? args[1] : args[2]
        }
        return args[0] != 0 ? args[0] : args[1]
    }

    // modulo operator
    symbols[.infix("%")] = { (args: [Double]) -> Double in args[0].truncatingRemainder(dividingBy: args[1]) }

    return symbols
}()

private func stringify(_ value: Any) -> String {
    guard let value = try? unwrap(value) else {
        return "nil"
    }
    switch value {
    case let number as NSNumber:
        guard let int = Int64(exactly: Double(number)) else {
            return "\(number)"
        }
        return "\(int)"
    case let value as NSAttributedString:
        return value.string
    default:
        return "\(value)"
    }
}

struct LayoutExpression {
    let evaluate: () throws -> Any
    let symbols: Set<String>

    init(evaluate: @escaping () throws -> Any,  symbols: Set<String>) {
        self.symbols = symbols
        if symbols.isEmpty, let value = try? evaluate() {
            // Very basic optimization
            self.evaluate = { value }
        } else {
            self.evaluate = evaluate
        }
    }

    private init(numberExpression: String, evaluator: @escaping Expression.Evaluator) {
        let expression = Expression(
            numberExpression,
            symbols: commonSymbols,
            evaluator: evaluator
        )
        var symbols = Set<String>()
        for symbol in expression.symbols {
            switch symbol {
            case let .constant(string), let .postfix(string):
                symbols.insert(string)
            default:
                break
            }
        }
        self.init(evaluate: expression.evaluate, symbols: symbols)
    }

    init(numberExpression: String, for node: LayoutNode) {
        self.init(numberExpression: numberExpression) { [unowned node] symbol, args in
            switch symbol {
            case let .constant(name):
                return try node.doubleValue(forSymbol: name)
            default:
                return nil
            }
        }
    }

    private init(percentageExpression: String,
                 for prop: String, in node: LayoutNode,
                 evaluator: @escaping Expression.Evaluator = { _ in nil }) {
        let prop = "parent.\(prop)"
        let expression = LayoutExpression(
            numberExpression: percentageExpression
        ) { [unowned node] symbol, args in
            if let value = try evaluator(symbol, args) {
                return value
            }
            switch symbol {
            case .postfix("%"):
                return try node.doubleValue(forSymbol: prop) / 100 * args[0]
            case let .constant(name):
                return try node.doubleValue(forSymbol: name)
            default:
                return nil
            }
        }
        var symbols = expression.symbols
        if symbols.remove("%") != nil {
            symbols.insert(prop)
        }
        self.init(evaluate: { try expression.evaluate() }, symbols: symbols)
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
            for: "width",
            in: node
        ) { [unowned node] symbol, args in
            switch symbol {
            case .constant("auto"):
                return Double(node.contentSize.width)
            default:
                return nil
            }
        }
        var symbols = expression.symbols
        if symbols.remove("auto") != nil {
            symbols.insert("contentSize.width")
        }
        self.init(evaluate: { try expression.evaluate() }, symbols: symbols)
    }

    init(heightExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(
            percentageExpression: heightExpression,
            for: "height",
            in: node
        ) { [unowned node] symbol, args in
            switch symbol {
            case .constant("auto"):
                return Double(node.contentSize.height)
            default:
                return nil
            }
        }
        var symbols = expression.symbols
        if symbols.remove("auto") != nil {
            symbols.insert("contentSize.height")
        }
        self.init(evaluate: { try expression.evaluate() }, symbols: symbols)
    }

    init(boolExpression: String, for node: LayoutNode) {
        let expression = LayoutExpression(numberExpression: boolExpression, for: node)
        self.init(
            evaluate: { try expression.evaluate() as! Double == 0 ? false : true },
            symbols: expression.symbols
        )
    }

    private init(anyExpression: String, type: RuntimeType, evaluator: @escaping AnyExpression.Evaluator) {
        let expression = AnyExpression(anyExpression, symbols: commonSymbols, evaluator: evaluator)
        var symbols = Set<String>()
        for case let .constant(string) in expression.symbols {
            symbols.insert(string)
        }
        self.init(
            evaluate: {
                guard let value = try type.cast(expression.evaluate()) else {
                    throw Expression.Error.message("Type mismatch")
                }
                return value
            },
            symbols: symbols
        )
    }

    init(anyExpression: String, type: RuntimeType, for node: LayoutNode) {
        self.init(anyExpression: anyExpression, type: type) { [unowned node] symbol, args in
            switch symbol {
            case let .constant(name):
                return try node.value(forSymbol: name)
            default:
                return nil
            }
        }
    }

    init(colorExpression: String, for node: LayoutNode) {
        func hexStringToColor(_ string: String) -> UIColor? {
            if string.hasPrefix("#") {
                var string = String(string.characters.dropFirst())
                switch string.characters.count {
                case 3:
                    string += "f"
                    fallthrough
                case 4:
                    let red = string.characters[string.index(string.startIndex, offsetBy: 0)]
                    let green = string.characters[string.index(string.startIndex, offsetBy: 1)]
                    let blue = string.characters[string.index(string.startIndex, offsetBy: 2)]
                    let alpha = string.characters[string.index(string.startIndex, offsetBy: 3)]
                    string = "\(red)\(red)\(green)\(green)\(blue)\(blue)\(alpha)\(alpha)"
                case 6:
                    string += "ff"
                default:
                    break
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
        }
        let expression = LayoutExpression(anyExpression: colorExpression, type: RuntimeType(UIColor.self)) {
            [unowned node] symbol, args in
            switch symbol {
            case let .constant(string):
                if let color = hexStringToColor(string) {
                    return color
                }
                return try node.value(forSymbol: string)
            case let .function("rgb", arity):
                if arity != 3 {
                    throw Expression.Error.arityMismatch(.function("rgb", arity: 3))
                }
                guard let r = args[0] as? Double, let g = args[1] as? Double, let b = args[2] as? Double else {
                    throw Expression.Error.message("Type mismatch")
                }
                return UIColor(red: CGFloat(r/255), green: CGFloat(g/255), blue: CGFloat(b/255), alpha: 1)
            case let .function("rgba", arity):
                if arity != 4 {
                    throw Expression.Error.arityMismatch(.function("rgba", arity: 4))
                }
                guard let r = args[0] as? Double, let g = args[1] as? Double,
                    let b = args[2] as? Double, let a = args[3] as? Double else {
                    throw Expression.Error.message("Type mismatch")
                }
                return UIColor(red: CGFloat(r/255), green: CGFloat(g/255), blue: CGFloat(b/255), alpha: CGFloat(a))
            default:
                return nil
            }
        }
        var symbols = expression.symbols
        for name in symbols {
            if hexStringToColor(name) != nil {
                symbols.remove(name)
            }
        }
        self.init(evaluate: { try expression.evaluate() }, symbols: symbols)
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

        var parts = [ExpressionPart]()
        var symbols = Set<String>()
        var range = expression.startIndex ..< expression.endIndex
        while let subrange = expression.range(of: "\\{[^}]*\\}", options: .regularExpression, range: range) {
            let string = expression[range.lowerBound ..< subrange.lowerBound]
            if !string.isEmpty {
                parts.append(.string(string))
            }
            let expressionString = expression[subrange].trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
            let expression = LayoutExpression(
                anyExpression: expressionString,
                type: RuntimeType(Any.self),
                for: node
            )
            parts.append(.expression(expression.evaluate))
            symbols.formUnion(expression.symbols)
            range = subrange.upperBound ..< range.upperBound
        }
        if !range.isEmpty {
            parts.append(.string(expression[range]))
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
                var result = ""
                for part in try expression.evaluate() as! [Any] {
                    result += stringify(part)
                }
                return result
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
                        htmlString += stringify(part)
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
                    switch part {
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
                var image: UIImage?
                var string = ""
                for part in try expression.evaluate() as! [Any] {
                    switch part {
                    case let part as UIImage:
                        image = part
                    default:
                        string += stringify(part)
                    }
                }
                string = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if let image = image {
                    if !string.isEmpty {
                         throw Expression.Error.message("Invalid image specifier `\(string)`")
                    }
                    return image
                }
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
            },
            symbols: expression.symbols
        )
    }

    init(enumExpression: String, type: RuntimeType, for node: LayoutNode) {
        guard case let .enum(_, values, _) = type.type else { preconditionFailure() }
        let expression = LayoutExpression(anyExpression: enumExpression, type: type) {
            [unowned node] symbol, args in
            switch symbol {
            case let .constant(name):
                if let enumValue = values[name] {
                    return enumValue
                }
                return try node.value(forSymbol: name)
            default:
                return nil
            }
        }
        var symbols = expression.symbols
        for name in symbols {
            if values[name] != nil {
                symbols.remove(name)
            }
        }
        self.init(evaluate: { try expression.evaluate() }, symbols: symbols)
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
                self.init(anyExpression: expression, type: type, for: node)
            }
        case .enum:
            self.init(enumExpression: expression, type: type, for: node)
        case .protocol:
            self.init(anyExpression: expression, type: type, for: node)
        }
    }
}
