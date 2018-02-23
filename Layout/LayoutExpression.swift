//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Foundation

private let ignoredSymbols: Set<Expression.Symbol> = [
    .variable("pi"),
    .variable("true"),
    .variable("false"),
    .variable("nil"),
]

private let colorSymbols: [AnyExpression.Symbol: AnyExpression.SymbolEvaluator] = [
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
]

private func cast(_ anyValue: Any, as type: RuntimeType) throws -> Any {
    guard let value = type.cast(anyValue) else {
        let value = try unwrap(anyValue)
        throw Expression.Error.message("\(Swift.type(of: value)) is not compatible with expected type \(type)")
    }
    return value
}

private func stringify(_ value: Any) throws -> String {
    switch try unwrap(value) {
    case let bundle as Bundle:
        return bundle.bundleIdentifier ?? bundle.bundleURL.absoluteString
    case let value:
        return AnyExpression.stringify(value)
    }
}

private func isNil(_ value: Any) -> Bool {
    return AnyExpression.isNil(value)
}

private func unwrap(_ value: Any) throws -> Any {
    guard let value = AnyExpression.unwrap(value) else {
        throw AnyExpression.Error.message("Unexpected nil value")
    }
    return value
}

private var _colorCache = [String: UIColor]()
private let colorLookup = { (string: String) -> Any? in
    if let color = _colorCache[string] {
        return color
    }
    if string.hasPrefix("#") {
        var string = String(string.dropFirst())
        switch string.count {
        case 3:
            string += "f"
            fallthrough
        case 4:
            let chars = Array(string)
            let red = chars[0]
            let green = chars[1]
            let blue = chars[2]
            let alpha = chars[3]
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
        if let color = UIColor.value(forKey: string) as? UIColor {
            _colorCache[string] = color
            return color
        }
    } else {
        let key = string + "Color"
        if UIColor.responds(to: Selector(key)), let color = UIColor.value(forKey: key) as? UIColor {
            _colorCache[string] = color
            return color
        }
    }
    // TODO: should we check for asset names here too?
    return nil
}

private func stringToAsset(_ string: String) throws -> (name: String, bundle: Bundle?, traits: UITraitCollection?) {
    let parts = string.components(separatedBy: ":")
    if parts.count == 1 {
        return (parts[0], nil, nil)
    }
    let identifier = parts[0].trimmingCharacters(in: .whitespaces)
    if identifier.contains("?") { // might be a ternary expression
        return (string, nil, nil)
    }
    if parts.count > 2 {
        throw Expression.Error.message("Invalid XCAsset name format: \(string)")
    }

    func bundleDescription(_ identifier: String) -> String {
        let nameOrIdentifier = identifier.contains(".") ? "identifier" : "name"
        return "\(nameOrIdentifier) \(identifier)"
    }

    var match: Bundle?
    for framework in Bundle.allFrameworks {
        let name = framework.infoDictionary?[kCFBundleNameKey as String] as? String
        guard framework.bundleIdentifier == identifier || name == identifier else {
            continue
        }

        var _bundle = framework
        // Check for a resource bundle with the same name/identifier as the framework
        // This is a common structure for bundled resources when using Cocoapods modules
        if let name = name,
            let bundle = framework.url(forResource: name, withExtension: "bundle").flatMap({
                Bundle(url: $0)
            }) {
            _bundle = bundle
        }

        #if arch(i386) || arch(x86_64)
            if match != nil, match != framework {
                throw Expression.Error.message("Multiple matches for bundle with \(bundleDescription(identifier))")
            }
            match = _bundle
        #else
            return (parts[1], _bundle, nil)
        #endif
    }
    for _bundle in Bundle.allBundles {
        let name = _bundle.infoDictionary?[kCFBundleNameKey as String] as? String
        guard _bundle.bundleIdentifier == identifier || name == identifier else {
            continue
        }

        #if arch(i386) || arch(x86_64)
            if match != nil, match != _bundle {
                throw Expression.Error.message("Multiple matches for bundle with \(bundleDescription(identifier))")
            }
            match = _bundle
        #else
            match = _bundle
            return (parts[1], match, nil)
        #endif
    }
    if let match = match {
        return (parts[1], match, nil)
    }
    throw Expression.Error.message("Could not locate bundle with \(bundleDescription(identifier))")
}

private var _colorAssetCache = [String: UIColor]()
func stringToColorAsset(_ string: String) throws -> UIColor? {
    if let color = _colorAssetCache[string] {
        return color
    }
    let (name, bundle, traits) = try stringToAsset(string)
    if #available(iOS 11.0, *) {
        if let color = UIColor(named: name, in: bundle, compatibleWith: traits) {
            _colorAssetCache[string] = color
            return color
        }
        if let bundle = bundle {
            throw Expression.Error.message("Color named `\(name)` not found in bundle \(bundle.bundleIdentifier ?? "<unknown>")")
        }
        return nil
    }
    if bundle != nil {
        throw Expression.Error.message("Named colors are only supported in iOS 11 and above")
    }
    return nil
}

private var _imageAssetCache = NSCache<NSString, UIImage>()
func stringToImageAsset(_ string: String) throws -> UIImage? {
    if let image = _imageAssetCache.object(forKey: string as NSString) {
        return image
    }
    let (name, bundle, traits) = try stringToAsset(string)
    if let image = UIImage(named: name, in: bundle, compatibleWith: traits) {
        _imageAssetCache.setObject(image, forKey: string as NSString)
        return image
    }
    if let bundle = bundle {
        throw Expression.Error.message("Image named `\(name)` not found in bundle \(bundle.bundleIdentifier ?? "<unknown>")")
    }
    return nil
}

struct LayoutExpression {
    let evaluate: () throws -> Any
    let symbols: Set<String>

    var isConstant: Bool { return symbols.isEmpty }

    init(evaluate: @escaping () throws -> Any, symbols: Set<String>) {
        self.symbols = symbols
        if symbols.isEmpty, let value = try? evaluate() {
            self.evaluate = { value }
        } else {
            self.evaluate = evaluate
        }
    }

    init?(doubleExpression: String, for node: LayoutNode) {
        self.init(
            anyExpression: doubleExpression,
            type: .double,
            for: node
        )
    }

    init?(boolExpression: String, for node: LayoutNode) {
        self.init(
            anyExpression: boolExpression,
            type: .bool,
            for: node
        )
    }

    private init?(percentageExpression: String,
                  for prop: String, in node: LayoutNode,
                  impureSymbols: (AnyExpression.Symbol) -> AnyExpression.SymbolEvaluator? = { _ in nil }) {
        guard let expression = LayoutExpression(
            anyExpression: percentageExpression,
            type: .cgFloat,
            impureSymbols: { symbol in
                if case .postfix("%") = symbol {
                    return { anyArgs in
                        guard let value = anyArgs[0] as? Double else {
                            throw Expression.Error.message("Type mismatch")
                        }
                        return try node.doubleValue(forSymbol: prop) / 100 * value
                    }
                }
                return impureSymbols(symbol)
            },
            for: node
        ) else {
            return nil
        }
        self.init(
            evaluate: expression.evaluate,
            symbols: Set(expression.symbols.map { $0 == "%" ? prop : $0 })
        )
    }

    init?(xExpression: String, for node: LayoutNode) {
        self.init(percentageExpression: xExpression, for: "parent.containerSize.width", in: node)
    }

    init?(yExpression: String, for node: LayoutNode) {
        self.init(percentageExpression: yExpression, for: "parent.containerSize.height", in: node)
    }

    private init?(sizeExpression: String, for prop: String, in node: LayoutNode) {
        let sizeProp = "inferredSize.\(prop)"
        guard let expression = LayoutExpression(
            percentageExpression: sizeExpression,
            for: "parent.containerSize.\(prop)", in: node,
            impureSymbols: { symbol in
                if case .variable("auto") = symbol {
                    return { _ in try node.doubleValue(forSymbol: sizeProp) }
                }
                return nil
            }
        ) else {
            return nil
        }
        self.init(
            evaluate: expression.evaluate,
            symbols: Set(expression.symbols.map { $0 == "auto" ? sizeProp : $0 })
        )
    }

    init?(widthExpression: String, for node: LayoutNode) {
        self.init(sizeExpression: widthExpression, for: "width", in: node)
    }

    init?(heightExpression: String, for node: LayoutNode) {
        self.init(sizeExpression: heightExpression, for: "height", in: node)
    }

    private init?(contentSizeExpression: String, for prop: String, in node: LayoutNode) {
        let sizeProp = "inferredContentSize.\(prop)"
        guard let expression = LayoutExpression(
            percentageExpression: contentSizeExpression,
            for: "containerSize.\(prop)", in: node,
            impureSymbols: { symbol in
                if case .variable("auto") = symbol {
                    return { _ in try node.doubleValue(forSymbol: sizeProp) }
                }
                return nil
            }
        ) else {
            return nil
        }
        self.init(
            evaluate: expression.evaluate,
            symbols: Set(expression.symbols.map { $0 == "auto" ? sizeProp : $0 })
        )
    }

    init?(contentWidthExpression: String, for node: LayoutNode) {
        self.init(contentSizeExpression: contentWidthExpression, for: "width", in: node)
    }

    init?(contentHeightExpression: String, for node: LayoutNode) {
        self.init(contentSizeExpression: contentHeightExpression, for: "height", in: node)
    }

    private init?(anyExpression: String,
                  type: RuntimeType,
                  nullable: Bool = false,
                  constants: @escaping (String) -> Any? = { _ in nil },
                  pureSymbols: (AnyExpression.Symbol) -> AnyExpression.SymbolEvaluator? = { _ in nil },
                  impureSymbols: (AnyExpression.Symbol) -> AnyExpression.SymbolEvaluator? = { _ in nil },
                  for node: LayoutNode) {
        do {
            self.init(
                anyExpression: try parseExpression(anyExpression),
                type: type,
                nullable: nullable,
                constants: constants,
                pureSymbols: pureSymbols,
                impureSymbols: impureSymbols,
                for: node
            )
        } catch {
            self.init(evaluate: { throw error }, symbols: [])
        }
    }

    private init?(anyExpression parsedExpression: ParsedLayoutExpression,
                  type: RuntimeType,
                  nullable: Bool,
                  constants: @escaping (String) -> Any? = { _ in nil },
                  pureSymbols: (AnyExpression.Symbol) -> AnyExpression.SymbolEvaluator? = { _ in nil },
                  impureSymbols: (AnyExpression.Symbol) -> AnyExpression.SymbolEvaluator? = { _ in nil },
                  macroReferences: [String] = [],
                  for node: LayoutNode) {
        if parsedExpression.isEmpty {
            return nil
        }
        func staticConstant(for key: String) throws -> Any? {
            var tail = key
            var head = ""
            while tail.isCapitalized, let range = tail.range(of: ".") {
                if !head.isEmpty {
                    head += "."
                }
                head += String(tail[..<range.lowerBound])
                tail = String(tail[range.upperBound...])
            }
            guard !head.isEmpty, let type = RuntimeType.type(named: head) else {
                return nil
            }
            switch type.type {
            case let .enum(_, values):
                return values[tail]
            case let .options(_, values):
                return values[tail]
            case let .any(type as NSObject.Type):
                if !tail.isEmpty {
                    guard type.responds(to: Selector(tail)) else {
                        var suffix = head.components(separatedBy: ".").last!
                        for prefix in ["UI", "NS"] {
                            if suffix.hasPrefix(prefix) {
                                suffix = String(suffix[prefix.endIndex ..< suffix.endIndex])
                                break
                            }
                        }
                        let newTail = tail + suffix
                        guard type.responds(to: Selector(newTail)) else {
                            throw SymbolError("Cannot access static property `\(tail)` of class \(head)", for: key)
                        }
                        return type.value(forKeyPath: newTail)
                    }
                    return type.value(forKeyPath: tail)
                }
                return type
            default:
                if !tail.isEmpty {
                    throw SymbolError("Cannot access static property `\(tail)` of type \(head)", for: key)
                }
                throw SymbolError("Unsupported type \(type)", for: key)
            }
        }
        func unescapedName(_ name: String) -> String {
            if name.first == "`" {
                return String(name.dropFirst().dropLast())
            }
            return name
        }
        var allConstants = [String: Any]()
        var macroSymbols = [String: Set<String>]()
        let expression = AnyExpression(
            parsedExpression.expression,
            impureSymbols: { symbol in
                if let fn = impureSymbols(symbol) {
                    return fn
                }
                switch symbol {
                case let .variable(name):
                    if "'\"".contains(name.first ?? " ") { return nil }
                    let key = unescapedName(name)
                    let macro = node.expression(forMacro: key)
                    let circular = (macro != nil) ? macroReferences.contains(key) : false
                    do {
                        if let macro = macro, !circular {
                            guard let macroExpression = LayoutExpression(
                                anyExpression: try parseExpression(macro),
                                type: .any,
                                nullable: nullable,
                                constants: constants,
                                pureSymbols: pureSymbols,
                                impureSymbols: impureSymbols,
                                macroReferences: macroReferences + [key],
                                for: node
                            ) else {
                                return { _ in throw SymbolError("Empty expression for `\(key)` macro", for: key) }
                            }
                            macroSymbols[key] = macroExpression.symbols
                            return { _ in
                                try SymbolError.wrap(macroExpression.evaluate, for: key)
                            }
                        } else if let value = try constants(key) ?? node.constantValue(forSymbol: key) ?? staticConstant(for: key) {
                            allConstants[name] = value
                            return nil
                        } else if circular {
                            return { [unowned node] _ in
                                do {
                                    return try node.value(forSymbol: key)
                                } catch {
                                    throw SymbolError("Macro `\(key)` references a nonexistent symbol of the same name (macros cannot reference themselves)", for: key)
                                }
                            }
                        } else if ignoredSymbols.contains(symbol) || pureSymbols(symbol) != nil {
                            return nil
                        } else {
                            return { [unowned node] _ in
                                try node.value(forSymbol: key)
                            }
                        }
                    } catch {
                        return { _ in throw error }
                    }
                case let .function(name, _):
                    let key = unescapedName(name)
                    do {
                        guard let value = (try constants(key) ?? node.constantValue(forSymbol: key)) else {
                            return nil
                        }
                        guard let fn = value as? AnyExpression.SymbolEvaluator else {
                            allConstants[name] = value
                            return nil
                        }
                        return { args in try SymbolError.wrap({ try fn(args) }, for: key) }
                    } catch {
                        return { _ in throw error }
                    }
                default:
                    return nil
                }
            },
            pureSymbols: { symbol in
                if let fn = pureSymbols(symbol) {
                    return fn
                }
                switch symbol {
                case let .variable(name):
                    return allConstants[name].map { value in
                        { _ in value }
                    }
                case let .function(name, .exactly(arity)):
                    guard let string = allConstants[name] as? String else {
                        return nil
                    }
                    let key = unescapedName(name)
                    do {
                        let formatString = try FormatString(string)
                        let types = formatString.types.map { RuntimeType($0) }
                        if arity > types.count {
                            // TODO: this should probably be a warning, since there are legitimate cases where this
                            // might arise - e.g. if a string doesn't use a param in one locale but does in others
                            throw SymbolError("Too many arguments (\(arity)) for format string '\(string)' for key `\(key)`", for: key)
                        } else if arity < types.count {
                            throw SymbolError("Too few arguments (\(arity)) for format string '\(string)' for key `\(key)`", for: key)
                        }
                        return { args in
                            let args = zip(types, args).map { type, value in
                                type.cast(value) ?? value
                            }
                            do {
                                return try formatString.print(arguments: args)
                            } catch {
                                throw SymbolError("\(error)", for: key)
                            }
                        }
                    } catch {
                        return { _ in throw SymbolError("\(error)", for: key) }
                    }
                case .infix(","):
                    return { args in
                        args.flatMap { $0 as? [Any] ?? [$0] }
                    }
                default:
                    return nil
                }
            }
        )
        self.init(
            evaluate: {
                let anyValue: Any = try expression.evaluate()
                if nullable, isNil(anyValue) {
                    return anyValue
                }
                return try cast(anyValue, as: type)
            },
            symbols: Set(expression.symbols.flatMap { symbol -> [String] in
                switch symbol {
                case _ where ignoredSymbols.contains(symbol):
                    return []
                case let .variable(name), let .array(name):
                    if let symbols = macroSymbols[name] {
                        return Array(symbols)
                    }
                    return [name]
                case let .postfix(string):
                    return [string]
                default:
                    return []
                }
            })
        )
    }

    private init?(interpolatedStringExpression expression: String, for node: LayoutNode) {
        enum ExpressionPart {
            case string(String)
            case expression(() throws -> Any)
        }

        do {
            var expressionSymbols = Set<String>()
            let parts: [ExpressionPart] = try parseStringExpression(expression).compactMap { part in
                switch part {
                case let .expression(parsedExpression):
                    guard let expression = LayoutExpression(
                        anyExpression: parsedExpression,
                        type: .any,
                        nullable: true,
                        for: node
                    ) else {
                        return nil
                    }
                    expressionSymbols.formUnion(expression.symbols)
                    return .expression(expression.evaluate)
                case let .string(string):
                    return .string(string)
                case .comment:
                    return nil
                }
            }
            if parts.isEmpty {
                return nil
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
                symbols: expressionSymbols
            )
        } catch {
            self.init(evaluate: { throw error }, symbols: [])
        }
    }

    init?(stringExpression: String, for node: LayoutNode) {
        guard let expression = LayoutExpression(interpolatedStringExpression: stringExpression, for: node) else {
            return nil
        }
        self.init(
            evaluate: {
                let parts = try expression.evaluate() as! [Any]
                if parts.count == 1, isNil(parts[0]) {
                    return ""
                }
                return try parts.map(stringify).joined()
            },
            symbols: expression.symbols
        )
    }

    init?(attributedStringExpression: String, for node: LayoutNode) {
        guard let expression = LayoutExpression(interpolatedStringExpression: attributedStringExpression, for: node) else {
            return nil
        }
        var symbols = expression.symbols
        for symbol in ["font", "textColor", "textAlignment", "lineBreakMode"] {
            if node.viewExpressionTypes[symbol] != nil {
                symbols.insert(symbol)
            }
        }
        func makeToken(_ index: Int) -> String {
            return "$(\(index))"
        }
        self.init(
            evaluate: {
                var substrings = [NSAttributedString]()
                var htmlString = ""
                for part in try expression.evaluate() as! [Any] {
                    switch part {
                    case let part as NSAttributedString:
                        while true {
                            let token = makeToken(substrings.count)
                            if htmlString.contains(token) {
                                substrings.append(NSAttributedString(string: token))
                            } else {
                                htmlString += token
                                substrings.append(part)
                                break
                            }
                        }
                    default:
                        htmlString += try stringify(part)
                    }
                }
                // LayoutLoader.atomic is needed here to avoid a concurrency issue caused by
                // the attributedString HTML parser spinning its own runloop instance
                // https://github.com/schibsted/layout/issues/9
                let result = try LayoutLoader.atomic {
                    try NSMutableAttributedString(
                        data: htmlString.data(using: .utf8, allowLossyConversion: true) ?? Data(),
                        options: [
                            NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html,
                            NSAttributedString.DocumentReadingOptionKey.characterEncoding: String.Encoding.utf8.rawValue,
                        ],
                        documentAttributes: nil
                    )
                }
                let correctFont: UIFont
                if symbols.contains("font"), let font = try node.value(forSymbol: "font") as? UIFont {
                    correctFont = font
                } else {
                    correctFont = UIFont.systemFont(ofSize: 17)
                }
                let range = NSMakeRange(0, result.string.utf16.count)
                result.enumerateAttributes(in: range, options: []) { attribs, range, _ in
                    var attribs = attribs
                    if let font = attribs[NSAttributedStringKey.font] as? UIFont {
                        let traits = font.fontDescriptor.symbolicTraits
                        var descriptor = correctFont.fontDescriptor
                        descriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
                        attribs[NSAttributedStringKey.font] = UIFont(descriptor: descriptor, size: correctFont.pointSize)
                        result.setAttributes(attribs, range: range)
                    }
                }
                if symbols.contains("textColor"),
                    let color = try node.value(forSymbol: "textColor") as? UIColor {
                    result.addAttribute(NSAttributedStringKey.foregroundColor, value: color, range: range)
                }

                // Paragraph style
                var alignment = NSTextAlignment.natural
                if symbols.contains("textAlignment") {
                    alignment = try node.value(forSymbol: "textAlignment") as! NSTextAlignment
                }
                var linebreakMode = NSLineBreakMode.byWordWrapping
                if symbols.contains("lineBreakMode") {
                    linebreakMode = try node.value(forSymbol: "lineBreakMode") as! NSLineBreakMode
                }
                // TODO: find a good way to support linespacing and paragraph spacing
                let style = NSMutableParagraphStyle()
                style.alignment = alignment
                style.lineBreakMode = linebreakMode
                result.addAttribute(NSAttributedStringKey.paragraphStyle, value: style, range: range)

                // Substitutions
                for (i, substring) in substrings.enumerated().reversed() {
                    let range = (result.string as NSString).range(of: makeToken(i))
                    if range.location != NSNotFound {
                        result.replaceCharacters(in: range, with: substring)
                    }
                }
                return result
            },
            symbols: symbols
        )
    }

    init?(fontExpression: String, for node: LayoutNode) {
        guard let expression = LayoutExpression(interpolatedStringExpression: fontExpression, for: node) else {
            return nil
        }

        func font(named name: String) -> UIFont? {
            if let font = UIFont(name: name, size: UIFont.defaultSize),
                font.fontName.lowercased() == name.lowercased() {
                return font
            }
            if let fontName = UIFont.fontNames(forFamilyName: name).first,
                let font = UIFont(name: fontName, size: UIFont.defaultSize) {
                let descriptor = UIFontDescriptor().withFamily(font.familyName)
                return UIFont(descriptor: descriptor, size: UIFont.defaultSize)
            }
            return nil
        }

        // Parse a stringified font part
        func fontPart(for string: String) -> Any? {
            switch string.lowercased() {
            case "italic":
                return UIFontDescriptorSymbolicTraits.traitItalic
            case "condensed":
                return UIFontDescriptorSymbolicTraits.traitCondensed
            case "expanded":
                return UIFontDescriptorSymbolicTraits.traitExpanded
            case "monospace", "monospaced":
                return UIFontDescriptorSymbolicTraits.traitMonoSpace
            case "system":
                return UIFont.systemFont(ofSize: UIFont.defaultSize)
            case "systembold", "system-bold":
                return UIFont.boldSystemFont(ofSize: UIFont.defaultSize)
            case "systemitalic", "system-italic":
                return UIFont.italicSystemFont(ofSize: UIFont.defaultSize)
            case "ultralight": // Helper, since the real attribute is mixed case
                return UIFont.Weight.ultraLight
            default:
                if let size = Double(string) {
                    return size
                }
                if string.hasSuffix("%"),
                    let size = Double(String(string.unicodeScalars.dropLast())) {
                    return UIFont.RelativeSize(factor: CGFloat(size / 100))
                }
                if let font = font(named: string) {
                    return font
                }
                if let fontStyle = RuntimeType.uiFontTextStyle.values[string] {
                    return fontStyle
                }
                if let fontWeight = RuntimeType.uiFont_Weight.values[string] {
                    return fontWeight
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
                        func processResult() -> Bool {
                            if !result.isEmpty {
                                let resultString = String(result)
                                result.removeAll()
                                if let prevName = fontName {
                                    // Might form a longer font name with the previous part
                                    fontName = "\(prevName) \(resultString)"
                                    if let part = font(named: fontName!) {
                                        if parts.last is UIFont {
                                            parts.removeLast()
                                        }
                                        parts.append(part)
                                        return true
                                    } else if fontPart(for: resultString) != nil, fontPart(for: prevName) == nil {
                                        // Error: prevName was not a valid specifier
                                        string = prevName
                                        return false
                                    }
                                } else {
                                    fontName = resultString
                                }
                                if let part = fontPart(for: resultString) {
                                    fontName = part is UIFont ? resultString : nil
                                    parts.append(part)
                                    return true
                                }
                                return false
                            }
                            return true
                        }
                        while let char = characters.popFirst() {
                            switch char {
                            case "'", "\"", "`":
                                if char == delimiter {
                                    if !result.isEmpty {
                                        let string = String(result)
                                        result.removeAll()
                                        guard let part = font(named: string) else {
                                            throw Expression.Error.message("Invalid font name or specifier `\(string)`")
                                        }
                                        fontName = string
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
                                _ = processResult()
                            default:
                                result.append(char)
                            }
                        }
                        if !processResult() {
                            throw Expression.Error.message("Invalid font name or specifier `\(string)`")
                        }
                        string = ""
                    }
                }
                for part in try expression.evaluate() as! [Any] {
                    let part = try unwrap(part)
                    switch part {
                    case let part as String:
                        string += part
                    default:
                        try processString()
                        parts.append(part)
                    }
                }
                try processString()
                return try UIFont.font(with: parts)
            },
            symbols: expression.symbols
        )
    }

    init?(colorExpression: String, type: RuntimeType = .uiColor, for node: LayoutNode) {
        func nameToColorAsset(_ name: String) throws -> Any {
            guard let color = try stringToColorAsset(name) else {
                throw Expression.Error.message("Invalid color name `\(name)`")
            }
            return try cast(color, as: type)
        }
        do {
            let parts = try parseStringExpression(colorExpression)
            if parts.count == 1 {
                let parsedExpression: ParsedLayoutExpression
                switch parts[0] {
                case let .string(name):
                    if let color = try stringToColorAsset(name) {
                        let color = try cast(color, as: type)
                        self.init(evaluate: { color }, symbols: [])
                        return
                    }
                    // Attempt to interpret as a color expression
                    guard let _parsedExpression = try? parseExpression(name) else {
                        throw Expression.Error.message("Invalid color name `\(name)`")
                    }
                    parsedExpression = _parsedExpression
                case let .expression(_parsedExpression):
                    parsedExpression = _parsedExpression
                case .comment:
                    return nil
                }
                guard let expression = LayoutExpression(
                    anyExpression: parsedExpression,
                    type: .any,
                    nullable: false,
                    pureSymbols: { symbol in
                        if case let .variable(name) = symbol, let color = colorLookup(name) {
                            return { _ in color }
                        }
                        return colorSymbols[symbol]
                    },
                    for: node
                ) else {
                    return nil
                }
                self.init(
                    evaluate: {
                        switch try expression.evaluate() {
                        case let name as String:
                            return try nameToColorAsset(name)
                        case let color:
                            return try cast(color, as: type)
                        }
                    },
                    symbols: expression.symbols
                )
            } else if #available(iOS 11.0, *) {
                guard let expression = LayoutExpression(stringExpression: colorExpression, for: node) else {
                    return nil
                }
                self.init(
                    evaluate: { try nameToColorAsset(expression.evaluate() as! String) },
                    symbols: expression.symbols
                )
            } else {
                throw Expression.Error.message("Named colors are only supported in iOS 11 and above")
            }
        } catch {
            self.init(evaluate: { throw error }, symbols: [])
        }
    }

    init?(imageExpression: String, type: RuntimeType = .uiImage, for node: LayoutNode) {
        func nameToImageAsset(_ name: String) throws -> Any {
            guard let image = try stringToImageAsset(name) else {
                throw Expression.Error.message("Image named `\(name)` not found in main bundle")
            }
            return try cast(image, as: type)
        }
        do {
            let parts = try parseStringExpression(imageExpression)
            if parts.count == 1 {
                let parsedExpression: ParsedLayoutExpression
                switch parts[0] {
                case let .string(name):
                    if let image = try stringToImageAsset(name) {
                        let image = try cast(image, as: type)
                        self.init(evaluate: { image }, symbols: [])
                        return
                    }
                    // Attempt to interpret as an image expression
                    guard let _parsedExpression = try? parseExpression(name) else {
                        throw Expression.Error.message("Invalid image name `\(name)`")
                    }
                    parsedExpression = _parsedExpression
                case let .expression(_parsedExpression):
                    parsedExpression = _parsedExpression
                case .comment:
                    return nil
                }
                guard let expression = LayoutExpression(
                    anyExpression: parsedExpression,
                    type: .any,
                    nullable: true,
                    for: node
                ) else {
                    return nil
                }
                self.init(
                    evaluate: {
                        let anyValue: Any
                        do {
                            anyValue = try expression.evaluate()
                        } catch let error as SymbolError {
                            // TODO: find a less stringly-typed solution for this
                            if imageExpression.description == error.symbol,
                                "\(error)".contains("Unknown property") {
                                throw Expression.Error.message("Image named `\(error.symbol)` not found in main bundle")
                            }
                            throw error
                        }
                        if isNil(anyValue) {
                            // Explicitly allow empty images
                            return UIImage()
                        }
                        switch anyValue {
                        case let name as String:
                            return try nameToImageAsset(name)
                        case let image:
                            return try cast(image, as: type)
                        }
                    },
                    symbols: expression.symbols
                )
            } else {
                guard let expression = LayoutExpression(stringExpression: imageExpression, for: node) else {
                    return nil
                }
                self.init(
                    evaluate: { try nameToImageAsset(expression.evaluate() as! String) },
                    symbols: expression.symbols
                )
            }
        } catch {
            self.init(evaluate: { throw error }, symbols: [])
        }
    }

    init?(urlExpression: String, for node: LayoutNode) {
        guard let expression = LayoutExpression(interpolatedStringExpression: urlExpression, for: node) else {
            return nil
        }
        // TODO: optimize for constant URLs
        // TODO: should empty string return nil instead of URL with empy path?
        self.init(
            evaluate: {
                let parts = try expression.evaluate() as! [Any]
                if parts.count == 1 {
                    switch parts[0] {
                    case let url as URL:
                        return url
                    case let path as String:
                        return urlFromString(path)
                    default:
                        if isNil(parts[0]) {
                            return urlFromString("")
                        }
                        return try cast(parts[0], as: .url)
                    }
                }
                return try urlFromString(parts.map(stringify).joined())
            },
            symbols: expression.symbols
        )
    }

    init?(urlRequestExpression: String, for node: LayoutNode) {
        guard let expression = LayoutExpression(interpolatedStringExpression: urlRequestExpression, for: node) else {
            return nil
        }
        // TODO: optimize for constant URLs
        self.init(
            evaluate: {
                let parts = try expression.evaluate() as! [Any]
                if parts.count == 1 {
                    switch parts[0] {
                    case let urlRequest as URLRequest:
                        return urlRequest
                    case let url as URL:
                        return URLRequest(url: url)
                    case let path as String:
                        return URLRequest(url: urlFromString(path))
                    default:
                        if isNil(parts[0]) {
                            return URLRequest(url: urlFromString(""))
                        }
                        return try cast(parts[0], as: .urlRequest)
                    }
                }
                return try URLRequest(url: urlFromString(parts.map(stringify).joined()))
            },
            symbols: expression.symbols
        )
    }

    init?(enumExpression: String, type: RuntimeType, for node: LayoutNode) {
        guard case let .enum(_, values) = type.type else { preconditionFailure() }
        self.init(
            anyExpression: enumExpression,
            type: type,
            constants: { name in values[name] },
            for: node
        )
    }

    init?(optionsExpression: String, type: RuntimeType, for node: LayoutNode) {
        guard case let .options(_, values) = type.type else { preconditionFailure() }
        self.init(
            anyExpression: optionsExpression,
            type: type,
            constants: { name in values[name] },
            for: node
        )
    }

    init?(selectorExpression: String, for node: LayoutNode) {
        guard let expression = LayoutExpression(stringExpression: selectorExpression, for: node) else {
            return nil
        }
        self.init(
            evaluate: { Selector(try expression.evaluate() as! String) },
            symbols: expression.symbols
        )
    }

    init?(outletExpression: String, for node: LayoutNode) {
        #if arch(i386) || arch(x86_64)
            // Pre-validate expression so we can produce more useful errors
            if let parts = try? parseStringExpression(outletExpression) {
                for part in parts {
                    switch part {
                    case let .expression(expression):
                        guard expression.symbols.count == 1,
                            case let .variable(name) = expression.symbols.first!,
                            let first = name.first, !"'\"".contains(first) else {
                            continue
                        }
                        var parent = node.parent
                        var invalidType: RuntimeType?
                        while let _parent = parent {
                            if let type = _parent._parameters[name] {
                                switch type.type {
                                case let .any(subtype):
                                    switch subtype {
                                    case is String.Type,
                                         is Int.Type,
                                         is Int32.Type,
                                         is Int64.Type,
                                         is UInt.Type,
                                         is UInt32.Type,
                                         is UInt64.Type,
                                         is Bool.Type:
                                        break
                                    default:
                                        invalidType = type
                                    }
                                default:
                                    invalidType = type
                                }
                            }
                            parent = _parent.parent
                        }
                        if let type = invalidType {
                            self.init(
                                evaluate: {
                                    throw Expression.Error.message("Outlet parameters must be of type String, not \(type)")
                                },
                                symbols: []
                            )
                            return
                        }
                    case .string, .comment:
                        continue
                    }
                }
            }
        #endif
        guard let expression = LayoutExpression(stringExpression: outletExpression, for: node) else {
            return nil
        }
        self.init(
            evaluate: { try expression.evaluate() as! String },
            symbols: expression.symbols
        )
    }

    init?(classExpression: String, class: AnyClass, for node: LayoutNode) {
        self.init(
            anyExpression: classExpression,
            type: RuntimeType(class: `class`),
            constants: classFromString,
            for: node
        )
    }

    init?(expression: String, type: RuntimeType, for node: LayoutNode) {
        switch type.type {
        case let .any(subtype):
            switch subtype {
            case is String.Type, is NSString.Type:
                self.init(stringExpression: expression, for: node)
            case is Selector.Type:
                self.init(selectorExpression: expression, for: node)
            case is NSAttributedString.Type:
                self.init(attributedStringExpression: expression, for: node)
            case is UIColor.Type:
                self.init(colorExpression: expression, type: type, for: node)
            case is UIImage.Type:
                self.init(imageExpression: expression, type: type, for: node)
            case is UIFont.Type:
                self.init(fontExpression: expression, for: node)
            case is URL.Type, is NSURL.Type:
                self.init(urlExpression: expression, for: node)
            case is URLRequest.Type, is NSURLRequest.Type:
                self.init(urlRequestExpression: expression, for: node)
            default:
                self.init(anyExpression: expression, type: type, nullable: false, for: node)
            }
        case let .class(subtype):
            self.init(classExpression: expression, class: subtype, for: node)
        case .struct:
            self.init(anyExpression: expression, type: type, nullable: false, for: node)
        case .enum:
            self.init(enumExpression: expression, type: type, for: node)
        case .options:
            self.init(optionsExpression: expression, type: type, for: node)
        case .pointer("CGColor"):
            self.init(colorExpression: expression, type: type, for: node)
        case .pointer("CGImage"):
            self.init(imageExpression: expression, type: type, for: node)
        case .pointer, .protocol, .array:
            self.init(anyExpression: expression, type: type, nullable: true, for: node)
        }
    }
}
