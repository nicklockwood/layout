//
//  Expression.swift
//  Expression
//
//  Version 0.6.0
//
//  Created by Nick Lockwood on 15/09/2016.
//  Copyright © 2016 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Expression
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import Foundation

/// Immutable wrapper for a parsed expression
/// Reusing the same Expression instance for multiple evaluations is more efficient
/// than creating a new one each time you wish to evaluate an expression string.
public class Expression: CustomStringConvertible {
    private let evaluator: Evaluator
    private let root: Subexpression

    /// Function prototype for evaluating an expression
    /// Return nil for an unrecognized symbol, or throw an error if the symbol is recognized
    /// but there is some other problem (e.g. wrong number of arguments for a function)
    public typealias Evaluator = (_ symbol: Expression.Symbol, _ args: [Double]) throws -> Double?

    /// Symbols that make up an expression
    public enum Symbol: CustomStringConvertible, Hashable {

        /// A named variable
        case variable(String)

        /// An infix operator
        case infix(String)

        /// A prefix operator
        case prefix(String)

        /// A postfix operator
        case postfix(String)

        /// A function accepting a number of arguments specified by `arity`
        case function(String, arity: Int)

        /// Evaluator for individual symbols
        public typealias Evaluator = (_ args: [Double]) throws -> Double

        /// The human-readable name of the symbol
        public var name: String {
            switch self {
            case let .variable(name),
                 let .infix(name),
                 let .prefix(name),
                 let .postfix(name),
                 let .function(name, _):
                return name
            }
        }

        /// The human-readable description of the symbol
        public var description: String {
            switch self {
            case let .variable(name):
                return "variable `\(name)`"
            case let .infix(name):
                return "infix operator `\(name)`"
            case let .prefix(name):
                return "prefix operator `\(name)`"
            case let .postfix(name):
                return "postfix operator `\(name)`"
            case let .function(name, _):
                return "function `\(name)()`"
            }
        }

        /// Required by the hashable protocol
        public var hashValue: Int {
            return name.hashValue
        }

        /// Required by the equatable protocol
        public static func ==(lhs: Symbol, rhs: Symbol) -> Bool {
            if case let .function(_, lhsarity) = lhs,
                case let .function(_, rhsarity) = rhs,
                lhsarity != rhsarity {
                return false
            }
            return lhs.description == rhs.description
        }
    }

    /// Runtime error when parsing or evaluating an expression
    public enum Error: Swift.Error, CustomStringConvertible, Equatable {

        /// An application-specific error
        case message(String)

        /// The parser encountered a sequence of characters it didn't recognize
        case unexpectedToken(String)

        /// The parser expected to find a delimiter (e.g. closing paren) but didn't
        case missingDelimiter(String)

        /// The specified constant, operator or function was not recognized
        case undefinedSymbol(Expression.Symbol)

        /// A function was called with the wrong number of arguments (arity)
        case arityMismatch(Expression.Symbol)

        /// The human-readable description of the error
        public var description: String {
            switch self {
            case let .message(message):
                return message
            case let .unexpectedToken(string):
                return "Unexpected token `\(string)`"
            case let .missingDelimiter(string):
                return "Missing `\(string)`"
            case let .undefinedSymbol(symbol):
                return "Undefined \(symbol)"
            case let .arityMismatch(symbol):
                let arity: Int
                switch symbol {
                case .variable:
                    arity = 0
                case .infix:
                    arity = 2
                case .postfix, .prefix:
                    arity = 1
                case let .function(_, requiredArity):
                    arity = requiredArity
                }
                let description = symbol.description
                return String(description.characters.first!).uppercased() +
                    String(description.characters.dropFirst()) +
                    " expects \(arity) argument\(arity == 1 ? "" : "s")"
            }
        }

        /// Equatable implementation
        static public func ==(lhs: Error, rhs: Error) -> Bool {
            switch (lhs, rhs) {
            case let (.message(lhs), .message(rhs)),
                 let (.unexpectedToken(lhs), .unexpectedToken(rhs)),
                 let (.missingDelimiter(lhs), .missingDelimiter(rhs)):
                return lhs == rhs
            case let (.undefinedSymbol(lhs), .undefinedSymbol(rhs)),
                 let (.arityMismatch(lhs), .arityMismatch(rhs)):
                return lhs == rhs
            case (.message, _),
                 (.unexpectedToken, _),
                 (.missingDelimiter, _),
                 (.undefinedSymbol, _),
                 (.arityMismatch, _):
                return false
            }
        }
    }

    /// Options for configuring an expression
    public struct Options: OptionSet {

        /// Disable caching of parsed expressions
        public static let noCache = Options(rawValue: 1 << 0)

        /// Disable optimizations such as constant substitution
        public static let noOptimize = Options(rawValue: 1 << 1)

        /// Enable standard boolean operators and constants
        public static let boolSymbols = Options(rawValue: 1 << 2)

        /// Packed bitfield of options
        public let rawValue: Int

        /// Designated initializer
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    /// Creates an Expression object from a string
    /// Optionally accepts some or all of:
    /// - A dictionary of constants for simple static values
    /// - A dictionary of symbols, for implementing custom functions and operators
    /// - A custom evaluator function for more complex symbol processing
    public init(_ expression: String,
                options: Options = [],
                constants: [String: Double] = [:],
                symbols: [Symbol: Symbol.Evaluator] = [:],
                evaluator: Evaluator? = nil) {

        // Build evaluator
        let boolSymbols = options.contains(.boolSymbols) ? Expression.boolSymbols : [:]
        self.evaluator = { symbol, args in
            // Try constants
            if case let .variable(name) = symbol, let value = constants[name] {
                return value
            }
            // Try symbols
            if let fn = symbols[symbol] {
                return try fn(args)
            }
            // Try custom evaluator
            if let value = try evaluator?(symbol, args) {
                return value
            }
            // Try default symbols
            if let fn = Expression.mathSymbols[symbol] {
                return try fn(args)
            }
            if let fn = boolSymbols[symbol] {
                return try fn(args)
            }
            // Check for arity mismatch
            if case let .function(called, arity) = symbol {
                let keys = Set(Expression.mathSymbols.keys).union(boolSymbols.keys).union(symbols.keys)
                for case let .function(name, requiredArity) in keys
                    where name == called && arity != requiredArity {
                        throw Error.arityMismatch(.function(called, arity: requiredArity))
                }
            }
            return nil
        }

        do {
            // Parse expression
            let root = try expression.parseSubexpression(usingCache: !options.contains(.noCache))
            guard !options.contains(.noOptimize) else {
                self.root = root
                return
            }

            // Optimize expression
            var pureSymbols = Dictionary<Symbol, Symbol.Evaluator>()
            for symbol in root.symbols {
                if case let .variable(name) = symbol, let value = constants[name] {
                    pureSymbols[symbol] = { _ in value }
                } else if symbols[symbol] != nil {
                    break // Can't be certain that it's pure
                } else if evaluator == nil, let fn = Expression.mathSymbols[symbol] ?? boolSymbols[symbol] {
                    // If there's no evaluator, we can assume that default symbols are pure
                    pureSymbols[symbol] = fn
                }
            }
            self.root = root.optimized(with: pureSymbols)
        } catch {
            // Parsing failed
            root = .error(error as! Error, expression)
        }
    }

    /// Evaluate the expression
    public func evaluate() throws -> Double {
        return try root.evaluate(evaluator)
    }

    // Stand math symbols
    private static let mathSymbols: [Symbol: Symbol.Evaluator] = {
        var symbols: [Symbol: ([Double]) -> Double] = [:]

        // constants
        symbols[.variable("pi")] = { _ in .pi }

        // infix operators
        symbols[.infix("+")] = { $0[0] + $0[1] }
        symbols[.infix("-")] = { $0[0] - $0[1] }
        symbols[.infix("*")] = { $0[0] * $0[1] }
        symbols[.infix("/")] = { $0[0] / $0[1] }
        symbols[.infix("%")] = { fmod($0[0], $0[1]) }

        // workaround for operator spacing rules
        symbols[.infix("+-")] = { $0[0] - $0[1] }
        symbols[.infix("*-")] = { $0[0] * -$0[1] }
        symbols[.infix("/-")] = { $0[0] / -$0[1] }

        // prefix operators
        symbols[.prefix("-")] = { -$0[0] }

        // functions - arity 1
        symbols[.function("sqrt", arity: 1)] = { sqrt($0[0]) }
        symbols[.function("floor", arity: 1)] = { floor($0[0]) }
        symbols[.function("ceil", arity: 1)] = { ceil($0[0]) }
        symbols[.function("round", arity: 1)] = { round($0[0]) }
        symbols[.function("cos", arity: 1)] = { cos($0[0]) }
        symbols[.function("acos", arity: 1)] = { acos($0[0]) }
        symbols[.function("sin", arity: 1)] = { sin($0[0]) }
        symbols[.function("asin", arity: 1)] = { asin($0[0]) }
        symbols[.function("tan", arity: 1)] = { tan($0[0]) }
        symbols[.function("atan", arity: 1)] = { atan($0[0]) }
        symbols[.function("abs", arity: 1)] = { abs($0[0]) }

        // functions - arity 2
        symbols[.function("pow", arity: 2)] = { pow($0[0], $0[1]) }
        symbols[.function("max", arity: 2)] = { max($0[0], $0[1]) }
        symbols[.function("min", arity: 2)] = { min($0[0], $0[1]) }
        symbols[.function("atan2", arity: 2)] = { atan2($0[0], $0[1]) }
        symbols[.function("mod", arity: 2)] = { fmod($0[0], $0[1]) }

        return symbols
    }()

    // Stand boolean symbols
    private static let boolSymbols: [Symbol: Symbol.Evaluator] = {
        var symbols: [Symbol: ([Double]) -> Double] = [:]

        // boolean constants
        symbols[.variable("true")] = { _ in 1 }
        symbols[.variable("false")] = { _ in 0 }

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

        return symbols
    }()

    /// Returns the optmized, pretty-printed expression if it was valid
    /// Otherwise, returns the original (invalid) expression string
    public var description: String { return root.description(parenthesized: false) }

    /// All symbols used in the expression
    public var symbols: Set<Symbol> { return root.symbols }
}

fileprivate enum Subexpression: CustomStringConvertible {
    case literal(Double)
    case infix(String)
    case prefix(String)
    case postfix(String)
    case operand(Expression.Symbol, [Subexpression])
    case error(Expression.Error, String)

    func evaluate(_ evaluator: Expression.Evaluator) throws -> Double {
        switch self {
        case let .literal(value):
            return value
        case let .operand(symbol, args):
            let argValues = try args.map { try $0.evaluate(evaluator) }
            if let value = try evaluator(symbol, argValues) {
                return value
            }
            if args.count == 3, case .infix("?:") = symbol, // Decompose ternary into two operators
                let lhs = try evaluator(.infix("?"), [argValues[0], argValues[1]]),
                let value = try evaluator(.infix(":"), [lhs, argValues[2]]) {
                return value
            }
            throw Expression.Error.undefinedSymbol(symbol)
        case let .error(error, _):
            throw error
        case .infix, .prefix, .postfix:
            preconditionFailure()
        }
    }

    func description(parenthesized: Bool) -> String {
        switch self {
        case let .literal(value):
            if let int = Int64(exactly: value) {
                return "\(int)"
            } else {
                return "\(value)"
            }
        case let .infix(string),
             let .prefix(string),
             let .postfix(string):
            return string
        case let .operand(symbol, args):
            switch symbol {
            case let .prefix(name):
                return "\(name)\(args[0])"
            case let .postfix(name):
                return "\(args[0])\(name)"
            case .infix("?:") where args.count == 3:
                let description = "\(args[0]) ? \(args[1]) : \(args[2])"
                return parenthesized ? "(\(description))" : description
            case let .infix(name):
                let description = "\(args[0]) \(name) \(args[1])"
                return parenthesized ? "(\(description))" : description
            case let .variable(name):
                return name
            case let .function(name, _):
                return "\(name)(\(args.map({ $0.description }).joined(separator: ", ")))"
            }
        case let .error(_, expression):
            return expression
        }
    }

    var description: String {
        return description(parenthesized: true)
    }

    var symbols: Set<Expression.Symbol> {
        switch self {
        case .literal, .error:
            return []
        case let .prefix(name):
            return [.prefix(name)]
        case let .postfix(name):
            return [.postfix(name)]
        case let .infix(name):
            return [.infix(name)]
        case let .operand(symbol, subexpressions):
            var symbols = Set([symbol])
            for subexpression in subexpressions {
                symbols.formUnion(subexpression.symbols)
            }
            return symbols
        }
    }

    func optimized(with pureSymbols: [Expression.Symbol: Expression.Symbol.Evaluator]) -> Subexpression {
        guard case .operand(let symbol, var args) = self else {
            return self
        }
        args = args.map { $0.optimized(with: pureSymbols) }
        guard let fn = pureSymbols[symbol] else {
            return .operand(symbol, args)
        }
        var argValues = [Double]()
        for arg in args {
            guard case let .literal(value) = arg else {
                return .operand(symbol, args)
            }
            argValues.append(value)
        }
        guard let result = try? fn(argValues) else {
            return .operand(symbol, args)
        }
        return .literal(result)
    }
}

fileprivate extension String.UnicodeScalarView {

    mutating func scanCharacters(_ matching: (UnicodeScalar) -> Bool) -> String? {
        var index = endIndex
        for (i, c) in enumerated() {
            if !matching(c) {
                index = self.index(startIndex, offsetBy: i)
                break
            }
        }
        if index > startIndex {
            let string = String(prefix(upTo: index))
            self = suffix(from: index)
            return string
        }
        return nil
    }

    mutating func scanCharacter(_ matching: (UnicodeScalar) -> Bool) -> String? {
        if let c = first, matching(c) {
            self = suffix(from: index(after: startIndex))
            return String(c)
        }
        return nil
    }

    mutating func scanCharacter(_ character: UnicodeScalar) -> Bool {
        return scanCharacter({ $0 == character }) != nil
    }

    mutating func skipWhitespace() -> Bool {
        if let _ = scanCharacters({
            switch $0 {
            case " ", "\t", "\n", "\r":
                return true
            default:
                return false
            }
        }) {
            return true
        }
        return false
    }

    mutating func parseNumericLiteral() throws -> Subexpression? {

        func scanInteger() -> String? {
            return scanCharacters {
                if case "0" ... "9" = $0 {
                    return true
                }
                return false
            }
        }

        func scanHex() -> String? {
            return scanCharacters {
                switch $0 {
                case "0" ... "9", "A" ... "F", "a" ... "f":
                    return true
                default:
                    return false
                }
            }
        }

        func scanExponent() -> String? {
            if let e = scanCharacter({ $0 == "e" || $0 == "E" }) {
                let sign = scanCharacter({ $0 == "-" || $0 == "+" }) ?? ""
                if let exponent = scanInteger() {
                    return e + sign + exponent
                }
            }
            return nil
        }

        guard var number = scanInteger() else {
            return nil
        }

        let endOfInt = self
        if scanCharacter(".") {
            if let fraction = scanInteger() {
                number += "." + fraction + (scanExponent() ?? "")
            } else {
                self = endOfInt
            }
            number += scanExponent() ?? ""
        } else if let exponent = scanExponent() {
            number += exponent
        } else if number == "0" {
            if scanCharacter("x") {
                number = "0x" + (scanHex() ?? "")
            }
        }
        guard let value = Double(number) else {
            throw Expression.Error.unexpectedToken(number)
        }
        return .literal(value)
    }

    mutating func parseOperator() -> Subexpression? {
        if let op = scanCharacter({ "(),:".unicodeScalars.contains($0) }) {
            return .infix(op)
        }
        if let op = scanCharacters({
            if "/=­-+!*%<>&|^~?".unicodeScalars.contains($0) {
                return true
            }
            switch $0.value {
            case 0x00A1 ... 0x00A7,
                 0x00A9, 0x00AB, 0x00AC, 0x00AE,
                 0x00B0 ... 0x00B1,
                 0x00B6, 0x00BB, 0x00BF, 0x00D7, 0x00F7,
                 0x2016 ... 0x2017,
                 0x2020 ... 0x2027,
                 0x2030 ... 0x203E,
                 0x2041 ... 0x2053,
                 0x2055 ... 0x205E,
                 0x2190 ... 0x23FF,
                 0x2500 ... 0x2775,
                 0x2794 ... 0x2BFF,
                 0x2E00 ... 0x2E7F,
                 0x3001 ... 0x3003,
                 0x3008 ... 0x3030:
                return true
            default:
                return false
            }
        }) {
            return .infix(op) // assume infix, will determine later
        }
        return nil
    }

    mutating func parseIdentifier() -> Subexpression? {

        func isHead(_ c: UnicodeScalar) -> Bool {
            switch c.value {
            case 0x41 ... 0x5A, // A-Z
                 0x61 ... 0x7A, // a-z
                 0x5F, 0x24, // _ and $
                 0x00A8, 0x00AA, 0x00AD, 0x00AF,
                 0x00B2 ... 0x00B5,
                 0x00B7 ... 0x00BA,
                 0x00BC ... 0x00BE,
                 0x00C0 ... 0x00D6,
                 0x00D8 ... 0x00F6,
                 0x00F8 ... 0x00FF,
                 0x0100 ... 0x02FF,
                 0x0370 ... 0x167F,
                 0x1681 ... 0x180D,
                 0x180F ... 0x1DBF,
                 0x1E00 ... 0x1FFF,
                 0x200B ... 0x200D,
                 0x202A ... 0x202E,
                 0x203F ... 0x2040,
                 0x2054,
                 0x2060 ... 0x206F,
                 0x2070 ... 0x20CF,
                 0x2100 ... 0x218F,
                 0x2460 ... 0x24FF,
                 0x2776 ... 0x2793,
                 0x2C00 ... 0x2DFF,
                 0x2E80 ... 0x2FFF,
                 0x3004 ... 0x3007,
                 0x3021 ... 0x302F,
                 0x3031 ... 0x303F,
                 0x3040 ... 0xD7FF,
                 0xF900 ... 0xFD3D,
                 0xFD40 ... 0xFDCF,
                 0xFDF0 ... 0xFE1F,
                 0xFE30 ... 0xFE44,
                 0xFE47 ... 0xFFFD,
                 0x10000 ... 0x1FFFD,
                 0x20000 ... 0x2FFFD,
                 0x30000 ... 0x3FFFD,
                 0x40000 ... 0x4FFFD,
                 0x50000 ... 0x5FFFD,
                 0x60000 ... 0x6FFFD,
                 0x70000 ... 0x7FFFD,
                 0x80000 ... 0x8FFFD,
                 0x90000 ... 0x9FFFD,
                 0xA0000 ... 0xAFFFD,
                 0xB0000 ... 0xBFFFD,
                 0xC0000 ... 0xCFFFD,
                 0xD0000 ... 0xDFFFD,
                 0xE0000 ... 0xEFFFD:
                return true
            default:
                return false
            }
        }

        func isTail(_ c: UnicodeScalar) -> Bool {
            switch c.value {
            case 0x30 ... 0x39, // 0-9
                 0x0300 ... 0x036F,
                 0x1DC0 ... 0x1DFF,
                 0x20D0 ... 0x20FF,
                 0xFE20 ... 0xFE2F:
                return true
            default:
                return isHead(c)
            }
        }

        func scanIdentifier() -> String? {
            if let head = scanCharacter({ isHead($0) || $0 == "@" || $0 == "#" }) {
                if let tail = scanCharacters({ isTail($0) || $0 == "." }) {
                    if tail.characters.last == "." {
                        self.insert(".", at: startIndex)
                        return head + String(tail.characters.dropLast())
                    }
                    return head + tail
                }
                return head
            }
            return nil
        }

        if let identifier = scanIdentifier() {
            return .operand(.variable(identifier), [])
        }
        return nil
    }

    mutating func parseSubexpression() throws -> Subexpression {
        var stack: [Subexpression] = []
        var scopes: [[Subexpression]] = []

        func precedence(_ op: String) -> Int {
            switch op {
            case "*", "/", "%":
                return 1
            case "<<", ">>":
                return -1
            case "<", "<=", ">=", ">":
                return -2
            case "==", "!=", "<>":
                return -3
            case "&", "|", "^":
                return -4
            case "&&", "||":
                return -5
            case ",", "?", ":":
                return -100
            default: // +, -, etc
                return 0
            }
        }

        func collapseStack(from i: Int) throws {
            guard stack.count > 1 else {
                return
            }
            let lhs = stack[i]
            switch lhs {
            case let .infix(name), let .postfix(name): // treat as prefix
                stack[i] = .prefix(name)
                try collapseStack(from: i)
            case let .prefix(name) where stack.count <= i + 1:
                throw Expression.Error.unexpectedToken(name)
            case let .prefix(name):
                let rhs = stack[i + 1]
                switch rhs {
                case .literal, .operand:
                    // prefix operator
                    stack[i ... i + 1] = [.operand(.prefix(name), [rhs])]
                    try collapseStack(from: 0)
                case .prefix, .infix, .postfix:
                    // nested prefix operator?
                    try collapseStack(from: i + 1)
                case let .error(error, _):
                    throw error
                }
            case .literal where stack.count <= i + 1:
                throw Expression.Error.unexpectedToken("\(lhs)")
            case let .operand(symbol, _) where stack.count <= i + 1:
                throw Expression.Error.unexpectedToken(symbol.name)
            case .literal, .operand:
                let rhs = stack[i + 1]
                switch rhs {
                case .literal:
                    // cannot follow an operand
                    throw Expression.Error.unexpectedToken("\(rhs)")
                case let .operand(symbol, _):
                    guard case let .variable(name) = symbol else {
                        // operand cannot follow another operand
                        // TODO: the symbol may not be the first part of the operand
                        throw Expression.Error.unexpectedToken(symbol.name)
                    }
                    // treat as a postfix operator
                    stack[i ... i + 1] = [.operand(.postfix(name), [lhs])]
                    try collapseStack(from: 0)
                case let .postfix(op1):
                    stack[i ... i + 1] = [.operand(.postfix(op1), [lhs])]
                    try collapseStack(from: 0)
                case let .infix(op1), let .prefix(op1): // treat as infix
                    guard stack.count > i + 2 else { // treat as postfix
                        stack[i ... i + 1] = [.operand(.postfix(op1), [lhs])]
                        try collapseStack(from: 0)
                        return
                    }
                    let rhs = stack[i + 2]
                    switch rhs {
                    case .prefix, .infix, .postfix: // treat as prefix
                        try collapseStack(from: i + 2)
                    case .literal where stack.count > i + 3, .operand where stack.count > i + 3:
                        if case let .infix(op2) = stack[i + 3], precedence(op1) >= precedence(op2) {
                            fallthrough
                        }
                        try collapseStack(from: i + 2)
                    case .literal, .operand:
                        if op1 == ":", case let .operand(.infix("?"), args) = lhs { // ternary
                            stack[i ... i + 2] = [.operand(.infix("?:"), [args[0], args[1], rhs])]
                        } else {
                            stack[i ... i + 2] = [.operand(.infix(op1), [lhs, rhs])]
                        }
                        try collapseStack(from: 0)
                    case let .error(error, _):
                        throw error
                    }
                case let .error(error, _):
                    throw error
                }
            case let .error(error, _):
                throw error
            }
        }

        var precededByWhitespace = true
        while let expression =
            try parseNumericLiteral() ??
            parseOperator() ??
            parseIdentifier() {

            // prepare for next iteration
            let followedByWhitespace = skipWhitespace() || count == 0

            switch expression {
            case .infix("("):
                scopes.append(stack)
                stack = []
            case .infix(")"):
                if let previous = stack.last, case let .infix(op) = previous {
                    stack[stack.count - 1] = .postfix(op)
                }
                try collapseStack(from: 0)
                guard var oldStack = scopes.last else {
                    throw Expression.Error.unexpectedToken(")")
                }
                scopes.removeLast()
                if let previous = oldStack.last {
                    if case let .operand(.variable(name), _) = previous {
                        // function call
                        oldStack.removeLast()
                        if stack.count > 0 {
                            // unwrap comma-delimited expression
                            while case let .operand(.infix(","), args) = stack.first! {
                                stack = args + stack.dropFirst()
                            }
                        }
                        stack = [.operand(.function(name, arity: stack.count), stack)]
                    }
                }
                stack = oldStack + stack
            case .infix(","):
                if let previous = stack.last, case let .infix(op) = previous {
                    stack[stack.count - 1] = .postfix(op)
                }
                stack.append(expression)
            case let .infix(name):
                switch (precededByWhitespace, followedByWhitespace) {
                case (true, true), (false, false):
                    stack.append(expression)
                case (true, false):
                    stack.append(.prefix(name))
                case (false, true):
                    stack.append(.postfix(name))
                }
            default:
                stack.append(expression)
            }

            // next iteration
            precededByWhitespace = followedByWhitespace
        }
        if let junk = scanCharacters({
            switch $0 {
            case " ", "\t", "\n", "\r":
                return false
            default:
                return true
            }
        }) {
            // Unexpected token
            throw Expression.Error.unexpectedToken(junk)
        }
        if stack.count < 1 {
            // Empty expression
            throw Expression.Error.unexpectedToken("")
        }
        try collapseStack(from: 0)
        if scopes.count > 0 {
            throw Expression.Error.missingDelimiter(")")
        }
        return stack[0]
    }
}

private var cache = [String: Subexpression]()
private let queue = DispatchQueue(label: "com.Expression")

public extension Expression {

    /// Clear the expression cache (useful for testing, or in low memory situations)
    static func clearCache() {
        queue.sync { cache.removeAll() }
    }
}

fileprivate extension String {
    func parseSubexpression(usingCache: Bool) throws -> Subexpression {

        // Check cache
        if usingCache {
            var cachedExpression: Subexpression?
            queue.sync { cachedExpression = cache[self] }
            if let expression = cachedExpression {
                return expression
            }
        }

        // Parse
        var characters = unicodeScalars
        let expression = try characters.parseSubexpression()

        // Store
        if usingCache {
            queue.async { cache[self] = expression }
        }
        return expression
    }
}
