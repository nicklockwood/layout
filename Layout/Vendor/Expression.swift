//
//  Expression.swift
//  Expression
//
//  Version 0.12.0
//
//  Created by Nick Lockwood on 15/09/2016.
//  Copyright © 2016 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Expression
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/// Immutable wrapper for a parsed expression
/// Reusing the same Expression instance for multiple evaluations is more efficient
/// than creating a new one each time you wish to evaluate an expression string.
public final class Expression: CustomStringConvertible {
    private let root: Subexpression

    /// Evaluator for individual symbols
    public typealias SymbolEvaluator = (_ args: [Double]) throws -> Double

    /// Type representing the arity (number of arguments) accepted by a function
    public enum Arity: ExpressibleByIntegerLiteral, CustomStringConvertible, Equatable {
        public typealias IntegerLiteralType = Int

        /// An exact number of arguments
        case exactly(Int)

        /// A minimum number of arguments
        case atLeast(Int)

        /// ExpressibleByIntegerLiteral constructor
        public init(integerLiteral value: Int) {
            self = .exactly(value)
        }

        /// The human-readable description of the arity
        public var description: String {
            switch self {
            case let .exactly(value):
                return "\(value) argument\(value == 1 ? "" : "s")"
            case let .atLeast(value):
                return "at least \(value) argument\(value == 1 ? "" : "s")"
            }
        }

        /// Equatable implementation
        /// Note: this works more like a contains() function if the
        /// lhs is a range and the rhs is an exact value. This allows
        /// foo(x) to match foo(...) in a symbols dictionary
        public static func == (lhs: Arity, rhs: Arity) -> Bool {
            switch (lhs, rhs) {
            case let (.exactly(lhs), .exactly(rhs)),
                 let (.atLeast(lhs), .atLeast(rhs)):
                return lhs == rhs
            case let (.atLeast(min), .exactly(rhs)):
                return rhs >= min
            case (.exactly, _),
                 (.atLeast, _):
                return false
            }
        }
    }

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
        case function(String, arity: Arity)

        /// A array of values accessed by index
        case array(String)

        /// The human-readable name of the symbol
        public var name: String {
            switch self {
            case let .variable(name),
                 let .infix(name),
                 let .prefix(name),
                 let .postfix(name),
                 let .function(name, _),
                 let .array(name):
                return name
            }
        }

        /// The human-readable description of the symbol
        public var description: String {
            switch self {
            case let .variable(name):
                return "variable \(demangle(name))"
            case let .infix(name):
                return "infix operator \(demangle(name))"
            case let .prefix(name):
                return "prefix operator \(demangle(name))"
            case let .postfix(name):
                return "postfix operator \(demangle(name))"
            case let .function(name, _):
                return "function \(demangle(name))()"
            case let .array(name):
                return "array \(demangle(name))[]"
            }
        }

        /// Required by the Hashable protocol
        public var hashValue: Int {
            return name.hashValue
        }

        /// Equatable implementation
        public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
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
        case undefinedSymbol(Symbol)

        /// A function was called with the wrong number of arguments (arity)
        case arityMismatch(Symbol)

        /// An array was accessed with an index outside the valid range
        case arrayBounds(Symbol, Double)

        /// The human-readable description of the error
        public var description: String {
            switch self {
            case let .message(message):
                return message
            case .unexpectedToken(""):
                return "Empty expression"
            case let .unexpectedToken(string):
                return "Unexpected token `\(string)`"
            case let .missingDelimiter(string):
                return "Missing `\(string)`"
            case let .undefinedSymbol(symbol):
                return "Undefined \(symbol)"
            case let .arityMismatch(symbol):
                let arity: Arity
                switch symbol {
                case .variable:
                    arity = 0
                case .infix("?:"):
                    arity = 3
                case .infix:
                    arity = 2
                case .postfix, .prefix:
                    arity = 1
                case let .function(_, requiredArity):
                    arity = requiredArity
                case .array:
                    arity = 1
                }
                let description = symbol.description
                return String(description.first!).uppercased() +
                    "\(description.dropFirst()) expects \(arity)"
            case let .arrayBounds(symbol, index):
                return "Index \(stringify(index)) out of bounds for \(symbol)"
            }
        }

        /// Equatable implementation
        public static func == (lhs: Error, rhs: Error) -> Bool {
            switch (lhs, rhs) {
            case let (.message(lhs), .message(rhs)),
                 let (.unexpectedToken(lhs), .unexpectedToken(rhs)),
                 let (.missingDelimiter(lhs), .missingDelimiter(rhs)):
                return lhs == rhs
            case let (.undefinedSymbol(lhs), .undefinedSymbol(rhs)),
                 let (.arityMismatch(lhs), .arityMismatch(rhs)):
                return lhs == rhs
            case let (.arrayBounds(lsymbol, lindex), .arrayBounds(rsymbol, rindex)):
                return lsymbol == rsymbol && lindex == rindex
            case (.message, _),
                 (.unexpectedToken, _),
                 (.missingDelimiter, _),
                 (.undefinedSymbol, _),
                 (.arityMismatch, _),
                 (.arrayBounds, _):
                return false
            }
        }
    }

    /// Options for configuring an expression
    public struct Options: OptionSet {

        /// Disable optimizations such as constant substitution
        public static let noOptimize = Options(rawValue: 1 << 1)

        /// Enable standard boolean operators and constants
        public static let boolSymbols = Options(rawValue: 1 << 2)

        /// Assume all functions and operators in `symbols` are "pure", i.e.
        /// they have no side effects, and always produce the same output
        /// for a given set of arguments
        public static let pureSymbols = Options(rawValue: 1 << 3)

        /// Packed bitfield of options
        public let rawValue: Int

        /// Designated initializer
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    /// Creates an Expression object from a string
    /// Optionally accepts some or all of:
    /// - A set of options for configuring expression behavior
    /// - A dictionary of constants for simple static values
    /// - A dictionary of arrays for static collections of related values
    /// - A dictionary of symbols, for implementing custom functions and operators
    public convenience init(
        _ expression: String,
        options: Options = [],
        constants: [String: Double] = [:],
        arrays: [String: [Double]] = [:],
        symbols: [Symbol: SymbolEvaluator] = [:]
    ) {
        self.init(
            Expression.parse(expression),
            options: options,
            constants: constants,
            arrays: arrays,
            symbols: symbols
        )
    }

    /// Alternative constructor that accepts a pre-parsed expression
    public convenience init(
        _ expression: ParsedExpression,
        options: Options = [],
        constants: [String: Double] = [:],
        arrays: [String: [Double]] = [:],
        symbols: [Symbol: SymbolEvaluator] = [:]
    ) {
        // Options
        let boolSymbols = options.contains(.boolSymbols) ? Expression.boolSymbols : [:]
        let shouldOptimize = !options.contains(.noOptimize)
        let pureSymbols = options.contains(.pureSymbols)

        // Evaluators
        func symbolEvaluator(for symbol: Symbol) -> SymbolEvaluator? {
            if let fn = symbols[symbol] {
                return fn
            } else if boolSymbols.isEmpty, case .infix("?:") = symbol,
                let lhs = symbols[.infix("?")], let rhs = symbols[.infix(":")] {
                return { args in try rhs([lhs([args[0], args[1]]), args[2]]) }
            }
            return nil
        }
        func defaultEvaluator(for symbol: Symbol) -> SymbolEvaluator {
            // Check default symbols
            if let fn = Expression.mathSymbols[symbol] ?? boolSymbols[symbol] {
                return fn
            }
            // Check for arity mismatch
            if case let .function(called, arity) = symbol {
                let keys = Set(Expression.mathSymbols.keys).union(boolSymbols.keys).union(symbols.keys)
                for case let .function(name, expected) in keys where name == called && arity != expected {
                    return { _ in throw Error.arityMismatch(.function(called, arity: expected)) }
                }
            }
            // Not found
            return { _ in throw Error.undefinedSymbol(symbol) }
        }
        func pureEvaluator(for symbol: Symbol) -> SymbolEvaluator {
            switch symbol {
            case let .variable(name):
                if let constant = constants[name] {
                    return { _ in constant }
                }
            case let .array(name):
                if let array = arrays[name] {
                    return { args in
                        guard let index = Int(exactly: floor(args[0])),
                            array.indices.contains(index) else {
                            throw Error.arrayBounds(symbol, args[0])
                        }
                        return array[index]
                    }
                }
            default:
                if let fn = symbolEvaluator(for: symbol) {
                    return fn
                }
            }
            return defaultEvaluator(for: symbol)
        }

        self.init(
            expression,
            impureSymbols: { symbol in
                switch symbol {
                case let .variable(name):
                    if constants[name] == nil, let fn = symbols[symbol] {
                        return fn
                    }
                case let .array(name):
                    if arrays[name] == nil, let fn = symbols[symbol] {
                        return fn
                    }
                default:
                    if !pureSymbols, let fn = symbolEvaluator(for: symbol) {
                        return fn
                    }
                }
                return shouldOptimize ? nil : pureEvaluator(for: symbol)
            },
            pureSymbols: pureEvaluator
        )
    }

    /// Alternative constructor for advanced usage
    /// Allows for dynamic symbol lookup or generation without any performance overhead
    /// Note that both math and boolean symbols are enabled by default - to disable them
    /// return `{ _ in throw Expression.Error.undefinedSymbol(symbol) }` from your lookup function
    public init(
        _ expression: ParsedExpression,
        impureSymbols: (Symbol) -> SymbolEvaluator?,
        pureSymbols: (Symbol) -> SymbolEvaluator? = { _ in nil }
    ) {
        root = expression.root.optimized(
            withImpureSymbols: impureSymbols,
            pureSymbols: {
                if let fn = pureSymbols($0) ?? Expression.mathSymbols[$0] ?? Expression.boolSymbols[$0] {
                    return fn
                }
                // Check for arity mismatch
                if case let .function(called, arity) = $0 {
                    let keys = Set(Expression.mathSymbols.keys).union(Expression.boolSymbols.keys)
                    for case let .function(name, expected) in keys where name == called && arity != expected {
                        return { _ in throw Error.arityMismatch(.function(called, arity: expected)) }
                    }
                }
                return nil
            }
        )
    }

    /// Alternative constructor with only pure symbols
    public convenience init(_ expression: ParsedExpression, pureSymbols: (Symbol) -> SymbolEvaluator?) {
        self.init(expression, impureSymbols: { _ in nil }, pureSymbols: pureSymbols)
    }

    /// Verify that the string is a valid identifier
    public static func isValidIdentifier(_ string: String) -> Bool {
        var characters = UnicodeScalarView(string)
        switch characters.parseIdentifier() ?? characters.parseEscapedIdentifier() {
        case .symbol(.variable, _, _)?:
            return characters.isEmpty
        default:
            return false
        }
    }

    /// Verify that the string is a valid operator
    public static func isValidOperator(_ string: String) -> Bool {
        var characters = UnicodeScalarView(string)
        guard case let .symbol(symbol, _, _)? = characters.parseOperator(),
            case let .infix(name) = symbol, name != "(", name != "[" else {
            return false
        }
        return characters.isEmpty
    }

    private static var cache = [String: Subexpression]()
    private static let queue = DispatchQueue(label: "com.Expression")

    // For testing
    static func isCached(_ expression: String) -> Bool {
        return queue.sync { cache[expression] != nil }
    }

    /// Parse an expression and optionally cache it for future use.
    /// Returns an opaque struct that cannot be evaluated but can be queried
    /// for symbols or used to construct an executable Expression instance
    public static func parse(_ expression: String, usingCache: Bool = true) -> ParsedExpression {

        // Check cache
        if usingCache {
            var cachedExpression: Subexpression?
            queue.sync { cachedExpression = cache[expression] }
            if let subexpression = cachedExpression {
                return ParsedExpression(root: subexpression)
            }
        }

        // Parse
        var characters = Substring.UnicodeScalarView(expression.unicodeScalars)
        let parsedExpression = parse(&characters)

        // Store
        if usingCache {
            queue.sync { cache[expression] = parsedExpression.root }
        }
        return parsedExpression
    }

    /// Parse an expression directly from the provided UnicodeScalarView,
    /// stopping when it reaches a token matching the `delimiter` string.
    /// This is convenient if you wish to parse expressions that are nested
    /// inside another string, e.g. for implementing string interpolation.
    /// If no delimiter string is specified, the method will throw an error
    /// if it encounters an unexpected token, but won't consume it
    public static func parse(
        _ input: inout Substring.UnicodeScalarView,
        upTo delimiters: String...
    ) -> ParsedExpression {

        var unicodeScalarView = UnicodeScalarView(input)
        let start = unicodeScalarView
        var subexpression: Subexpression
        do {
            subexpression = try unicodeScalarView.parseSubexpression(upTo: delimiters)
        } catch {
            let expression = String(start.prefix(upTo: unicodeScalarView.startIndex))
            subexpression = .error(error as! Error, expression)
        }
        input = Substring.UnicodeScalarView(unicodeScalarView)
        return ParsedExpression(root: subexpression)
    }

    /// Clear the expression cache (useful for testing, or in low memory situations)
    public static func clearCache(for expression: String? = nil) {
        queue.sync {
            if let expression = expression {
                cache.removeValue(forKey: expression)
            } else {
                cache.removeAll()
            }
        }
    }

    /// Returns the optmized, pretty-printed expression if it was valid
    /// Otherwise, returns the original (invalid) expression string
    public var description: String { return root.description }

    /// All symbols used in the expression
    public var symbols: Set<Symbol> { return root.symbols }

    /// Evaluate the expression
    public func evaluate() throws -> Double {
        return try root.evaluate()
    }

    /// Standard math symbols
    public static let mathSymbols: [Symbol: SymbolEvaluator] = {
        var symbols: [Symbol: SymbolEvaluator] = [:]

        // constants
        symbols[.variable("pi")] = { _ in .pi }

        // infix operators
        symbols[.infix("+")] = { $0[0] + $0[1] }
        symbols[.infix("-")] = { $0[0] - $0[1] }
        symbols[.infix("*")] = { $0[0] * $0[1] }
        symbols[.infix("/")] = { $0[0] / $0[1] }
        symbols[.infix("%")] = { fmod($0[0], $0[1]) }

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
        symbols[.function("atan2", arity: 2)] = { atan2($0[0], $0[1]) }
        symbols[.function("mod", arity: 2)] = { fmod($0[0], $0[1]) }

        // functions - variadic
        symbols[.function("max", arity: .atLeast(2))] = { $0.reduce($0[0]) { max($0, $1) } }
        symbols[.function("min", arity: .atLeast(2))] = { $0.reduce($0[0]) { min($0, $1) } }

        return symbols
    }()

    /// Standard boolean symbols
    public static let boolSymbols: [Symbol: SymbolEvaluator] = {
        var symbols: [Symbol: SymbolEvaluator] = [:]

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
}

/// An opaque wrapper for a parsed expression
public struct ParsedExpression: CustomStringConvertible {
    fileprivate let root: Subexpression

    /// Returns the pretty-printed expression if it was valid
    /// Otherwise, returns the original (invalid) expression string
    public var description: String { return root.description }

    /// All symbols used in the expression
    public var symbols: Set<Expression.Symbol> { return root.symbols }

    /// Any error detected during parsing
    public var error: Expression.Error? {
        if case let .error(error, _) = root {
            return error
        }
        return nil
    }
}

// The internal expression implementation
private enum Subexpression: CustomStringConvertible {
    case literal(Double)
    case symbol(Expression.Symbol, [Subexpression], Expression.SymbolEvaluator)
    case error(Expression.Error, String)

    var isOperand: Bool {
        switch self {
        case let .symbol(symbol, args, _) where args.isEmpty:
            switch symbol {
            case .infix, .prefix, .postfix:
                return false
            default:
                return true
            }
        case .symbol, .literal:
            return true
        case .error:
            return false
        }
    }

    func evaluate() throws -> Double {
        switch self {
        case let .literal(value):
            return value
        case let .symbol(_, args, fn):
            let argValues = try args.map { try $0.evaluate() }
            return try fn(argValues)
        case let .error(error, _):
            throw error
        }
    }

    var description: String {
        func arguments(_ args: [Subexpression]) -> String {
            return args.map {
                if case .symbol(.infix(","), _, _) = $0 {
                    return "(\($0))"
                }
                return $0.description
            }.joined(separator: ", ")
        }
        switch self {
        case let .literal(value):
            return stringify(value)
        case let .symbol(symbol, args, _):
            guard isOperand else {
                return demangle(symbol.name)
            }
            func needsSeparation(_ lhs: String, _ rhs: String) -> Bool {
                let lhs = lhs.unicodeScalars.last!, rhs = rhs.unicodeScalars.first!
                return lhs == "." || (isOperator(lhs) || lhs == "-") == (isOperator(rhs) || rhs == "-")
            }
            switch symbol {
            case let .prefix(name):
                let arg = args[0]
                let description = "\(arg)"
                switch arg {
                case .symbol(.infix, _, _), .symbol(.postfix, _, _), .error,
                     .symbol where needsSeparation(name, description):
                    return "\(demangle(name))(\(description))" // Parens required
                case .symbol, .literal:
                    return "\(demangle(name))\(description)" // No parens needed
                }
            case let .postfix(name):
                let arg = args[0]
                let description = "\(arg)"
                switch arg {
                case .symbol(.infix, _, _), .symbol(.postfix, _, _), .error,
                     .symbol where needsSeparation(description, name):
                    return "(\(description))\(demangle(name))" // Parens required
                case .symbol, .literal:
                    return "\(description)\(demangle(name))" // No parens needed
                }
            case .infix(","):
                return "\(args[0]), \(args[1])"
            case .infix("?:") where args.count == 3:
                return "\(args[0]) ? \(args[1]) : \(args[2])"
            case let .infix(name):
                let lhs = args[0]
                let lhsDescription: String
                switch lhs {
                case let .symbol(.infix(opName), _, _) where !op(opName, takesPrecedenceOver: name):
                    lhsDescription = "(\(lhs))"
                default:
                    lhsDescription = "\(lhs)"
                }
                let rhs = args[1]
                let rhsDescription: String
                switch rhs {
                case let .symbol(.infix(opName), _, _) where op(name, takesPrecedenceOver: opName):
                    rhsDescription = "(\(rhs))"
                default:
                    rhsDescription = "\(rhs)"
                }
                return "\(lhsDescription) \(demangle(name)) \(rhsDescription)"
            case let .variable(name):
                return demangle(name)
            case let .function(name, _):
                return "\(demangle(name))(\(arguments(args)))"
            case let .array(name):
                return "\(demangle(name))[\(arguments(args))]"
            }
        case let .error(_, expression):
            return expression
        }
    }

    var symbols: Set<Expression.Symbol> {
        switch self {
        case .literal, .error:
            return []
        case let .symbol(symbol, subexpressions, _):
            var symbols = Set([symbol])
            for subexpression in subexpressions {
                symbols.formUnion(subexpression.symbols)
            }
            return symbols
        }
    }

    func optimized(
        withImpureSymbols impureSymbols: (Expression.Symbol) -> Expression.SymbolEvaluator?,
        pureSymbols: (Expression.Symbol) -> Expression.SymbolEvaluator?
    ) -> Subexpression {

        guard case .symbol(let symbol, var args, _) = self else {
            return self
        }
        args = args.map {
            $0.optimized(withImpureSymbols: impureSymbols, pureSymbols: pureSymbols)
        }
        if let fn = impureSymbols(symbol) {
            return .symbol(symbol, args, fn)
        }
        guard let fn = pureSymbols(symbol) else {
            return .symbol(symbol, args, { _ in
                throw Expression.Error.undefinedSymbol(symbol)
            })
        }
        var argValues = [Double]()
        for arg in args {
            guard case let .literal(value) = arg else {
                return .symbol(symbol, args, fn)
            }
            argValues.append(value)
        }
        guard let result = try? fn(argValues) else {
            return .symbol(symbol, args, fn)
        }
        return .literal(result)
    }
}

// Produce a printable number, without redundant decimal places
private func stringify(_ number: Double) -> String {
    if let int = Int64(exactly: number) {
        return "\(int)"
    }
    return "\(number)"
}

// Escape unprintable characters in a parsed symbol name
private func demangle(_ symbolName: String) -> String {
    guard let delimiter = symbolName.first, "`'\"".contains(delimiter),
        symbolName.count > 1, symbolName.last == delimiter else {
        return symbolName
    }
    var result = "\(delimiter)"
    for char in symbolName.unicodeScalars.dropFirst().dropLast() {
        switch char.value {
        case 0:
            result += "\\0"
        case 9:
            result += "\\t"
        case 10:
            result += "\\n"
        case 13:
            result += "\\r"
        case 0x20 ..< 0x7F,
             _ where isOperator(char) || isIdentifier(char):
            result.append(Character(char))
        default:
            result += "\\u{\(String(format: "%X", char.value))}"
        }
    }
    result.append(delimiter)
    return result
}

private let placeholder: Expression.SymbolEvaluator = { _ in
    preconditionFailure()
}

private let assignmentOperators = Set([
    "=", "*=", "/=", "%=", "+=", "-=",
    "<<=", ">>=", "&=", "^=", "|=", ":=",
])

private let comparisonOperators = Set([
    "<", "<=", ">=", ">",
    "==", "!=", "<>", "===", "!==",
    "lt", "le", "lte", "gt", "ge", "gte", "eq", "ne",
])

private func op(_ lhs: String, takesPrecedenceOver rhs: String) -> Bool {

    // https://github.com/apple/swift-evolution/blob/master/proposals/0077-operator-precedence.md
    func precedence(of op: String) -> Int {
        switch op {
        case "<<", ">>", ">>>": // bitshift
            return 2
        case "*", "/", "%", "&": // multiplication
            return 1
        case "..", "...", "..<": // range formation
            return -1
        case "is", "as", "isa": // casting
            return -2
        case "??", "?:": // null-coalescing
            return -3
        case _ where comparisonOperators.contains(op): // comparison
            return -4
        case "&&", "and": // and
            return -5
        case "||", "or": // or
            return -6
        case "?", ":": // ternary
            return -7
        case _ where assignmentOperators.contains(op): // assignment
            return -8
        case ",":
            return -100
        default: // +, -, |, ^, etc
            return 0
        }
    }

    func isRightAssociative(_ op: String) -> Bool {
        return comparisonOperators.contains(op) || assignmentOperators.contains(op)
    }

    let p1 = precedence(of: lhs)
    let p2 = precedence(of: rhs)
    if p1 == p2 {
        return !isRightAssociative(lhs)
    }
    return p1 > p2
}

private func isOperator(_ char: UnicodeScalar) -> Bool {
    // Strangely, this is faster than switching on value
    if "/=­+!*%<>&|^~?:".unicodeScalars.contains(char) {
        return true
    }
    switch char.value {
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
}

private func isIdentifierHead(_ c: UnicodeScalar) -> Bool {
    switch c.value {
    case 0x5F, 0x23, 0x24, 0x40, // _ # $ @
         0x41 ... 0x5A, // A-Z
         0x61 ... 0x7A, // a-z
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

private func isIdentifier(_ c: UnicodeScalar) -> Bool {
    switch c.value {
    case 0x30 ... 0x39, // 0-9
         0x0300 ... 0x036F,
         0x1DC0 ... 0x1DFF,
         0x20D0 ... 0x20FF,
         0xFE20 ... 0xFE2F:
        return true
    default:
        return isIdentifierHead(c)
    }
}

// Workaround for horribly slow Substring.UnicodeScalarView perf

private struct UnicodeScalarView {
    public typealias Index = String.UnicodeScalarView.Index

    private let characters: String.UnicodeScalarView
    public private(set) var startIndex: Index
    public private(set) var endIndex: Index

    public init(_ unicodeScalars: String.UnicodeScalarView) {
        characters = unicodeScalars
        startIndex = characters.startIndex
        endIndex = characters.endIndex
    }

    public init(_ unicodeScalars: Substring.UnicodeScalarView) {
        self.init(String.UnicodeScalarView(unicodeScalars))
    }

    public init(_ string: String) {
        self.init(string.unicodeScalars)
    }

    public var first: UnicodeScalar? {
        return isEmpty ? nil : characters[startIndex]
    }

    public var isEmpty: Bool {
        return startIndex >= endIndex
    }

    public subscript(_ index: Index) -> UnicodeScalar {
        return characters[index]
    }

    public func index(after index: Index) -> Index {
        return characters.index(after: index)
    }

    public func prefix(upTo index: Index) -> UnicodeScalarView {
        var view = UnicodeScalarView(characters)
        view.startIndex = startIndex
        view.endIndex = index
        return view
    }

    public func suffix(from index: Index) -> UnicodeScalarView {
        var view = UnicodeScalarView(characters)
        view.startIndex = index
        view.endIndex = endIndex
        return view
    }

    public mutating func popFirst() -> UnicodeScalar? {
        if isEmpty {
            return nil
        }
        let char = characters[startIndex]
        startIndex = characters.index(after: startIndex)
        return char
    }

    /// Returns the remaining characters
    fileprivate var unicodeScalars: Substring.UnicodeScalarView {
        return characters[startIndex ..< endIndex]
    }
}

private typealias _UnicodeScalarView = UnicodeScalarView
private extension String {
    init(_ unicodeScalarView: _UnicodeScalarView) {
        self.init(unicodeScalarView.unicodeScalars)
    }
}

private extension Substring.UnicodeScalarView {
    init(_ unicodeScalarView: _UnicodeScalarView) {
        self.init(unicodeScalarView.unicodeScalars)
    }
}

// Expression parsing logic
private extension UnicodeScalarView {

    mutating func scanCharacters(_ matching: (UnicodeScalar) -> Bool) -> String? {
        var index = startIndex
        while index < endIndex {
            if !matching(self[index]) {
                break
            }
            index = self.index(after: index)
        }
        if index > startIndex {
            let string = String(prefix(upTo: index))
            self = suffix(from: index)
            return string
        }
        return nil
    }

    mutating func scanCharacter(_ matching: (UnicodeScalar) -> Bool = { _ in true }) -> String? {
        if let c = first, matching(c) {
            self = suffix(from: index(after: startIndex))
            return String(c)
        }
        return nil
    }

    mutating func scanCharacter(_ character: UnicodeScalar) -> Bool {
        return scanCharacter({ $0 == character }) != nil
    }

    mutating func scanToEndOfToken() -> String? {
        return scanCharacters({
            switch $0 {
            case " ", "\t", "\n", "\r":
                return false
            default:
                return true
            }
        })
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

    mutating func parseDelimiter(_ delimiters: [String]) -> Bool {
        outer: for delimiter in delimiters {
            let start = self
            for char in delimiter.unicodeScalars {
                guard scanCharacter(char) else {
                    self = start
                    continue outer
                }
            }
            self = start
            return true
        }
        return false
    }

    mutating func parseNumericLiteral() -> Subexpression? {

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
            let start = self
            if let e = scanCharacter({ $0 == "e" || $0 == "E" }) {
                let sign = scanCharacter({ $0 == "-" || $0 == "+" }) ?? ""
                if let exponent = scanInteger() {
                    return e + sign + exponent
                }
            }
            self = start
            return nil
        }

        func scanNumber() -> String? {
            var number: String
            var endOfInt = self
            if let integer = scanInteger() {
                if integer == "0", scanCharacter("x") {
                    return "0x\(scanHex() ?? "")"
                }
                endOfInt = self
                if scanCharacter(".") {
                    guard let fraction = scanInteger() else {
                        self = endOfInt
                        return integer
                    }
                    number = "\(integer).\(fraction)"
                } else {
                    number = integer
                }
            } else if scanCharacter(".") {
                guard let fraction = scanInteger() else {
                    self = endOfInt
                    return nil
                }
                number = ".\(fraction)"
            } else {
                return nil
            }
            if let exponent = scanExponent() {
                number += exponent
            }
            return number
        }

        guard let number = scanNumber() else {
            return nil
        }
        guard let value = Double(number) else {
            return .error(.unexpectedToken(number), number)
        }
        return .literal(value)
    }

    mutating func parseOperator() -> Subexpression? {
        if var op = scanCharacters({ $0 == "." }) ?? scanCharacters({ $0 == "-" }) {
            if let tail = scanCharacters(isOperator) {
                op += tail
            }
            return .symbol(.infix(op), [], placeholder)
        }
        if let op = scanCharacters(isOperator) ??
            scanCharacter({ "([,".unicodeScalars.contains($0) }) {
            return .symbol(.infix(op), [], placeholder)
        }
        return nil
    }

    mutating func parseIdentifier() -> Subexpression? {
        func scanIdentifier() -> String? {
            var start = self
            var identifier = ""
            if scanCharacter(".") {
                identifier = "."
            } else if let head = scanCharacter(isIdentifierHead) {
                identifier = head
                start = self
                if scanCharacter(".") {
                    identifier.append(".")
                }
            } else {
                return nil
            }
            while let tail = scanCharacters(isIdentifier) {
                identifier += tail
                start = self
                if scanCharacter(".") {
                    identifier.append(".")
                }
            }
            if identifier.hasSuffix(".") {
                self = start
                if identifier == "." {
                    return nil
                }
                identifier = String(identifier.unicodeScalars.dropLast())
            } else if scanCharacter("'") {
                identifier.append("'")
            }
            return identifier
        }

        guard let identifier = scanIdentifier() else {
            return nil
        }
        return .symbol(.variable(identifier), [], placeholder)
    }

    mutating func parseEscapedIdentifier() -> Subexpression? {
        guard let delimiter = first,
            var string = scanCharacter({ "`'\"".unicodeScalars.contains($0) }) else {
            return nil
        }
        while let part = scanCharacters({ $0 != delimiter && $0 != "\\" }) {
            string += part
            if scanCharacter("\\"), let c = popFirst() {
                switch c {
                case "0":
                    string += "\0"
                case "t":
                    string += "\t"
                case "n":
                    string += "\n"
                case "r":
                    string += "\r"
                case "u" where scanCharacter("{"):
                    let hex = scanCharacters({
                        switch $0 {
                        case "0" ... "9", "A" ... "F", "a" ... "f":
                            return true
                        default:
                            return false
                        }
                    }) ?? ""
                    guard scanCharacter("}") else {
                        guard let junk = scanToEndOfToken() else {
                            return .error(.missingDelimiter("}"), string)
                        }
                        return .error(.unexpectedToken(junk), string)
                    }
                    guard !hex.isEmpty else {
                        return .error(.unexpectedToken("}"), string)
                    }
                    guard let codepoint = Int(hex, radix: 16),
                        let c = UnicodeScalar(codepoint) else {
                        // TODO: better error for invalid codepoint?
                        return .error(.unexpectedToken(hex), string)
                    }
                    string.append(Character(c))
                default:
                    string.append(Character(c))
                }
            }
        }
        guard scanCharacter(delimiter) else {
            return .error(string == String(delimiter) ?
                .unexpectedToken(string) : .missingDelimiter(String(delimiter)), string)
        }
        string.append(Character(delimiter))
        return .symbol(.variable(string), [], placeholder)
    }

    mutating func parseSubexpression(upTo delimiters: [String]) throws -> Subexpression {
        var stack: [Subexpression] = []

        func collapseStack(from i: Int) throws {
            guard stack.count > i + 1 else {
                return
            }
            let lhs = stack[i]
            let rhs = stack[i + 1]
            if lhs.isOperand {
                if rhs.isOperand {
                    guard case let .symbol(.postfix(op), args, _) = lhs else {
                        // Cannot follow an operand
                        throw Expression.Error.unexpectedToken("\(rhs)")
                    }
                    // Assume postfix operator was actually an infix operator
                    stack[i] = args[0]
                    stack.insert(.symbol(.infix(op), [], placeholder), at: i + 1)
                    try collapseStack(from: i)
                } else if case let .symbol(symbol, _, _) = rhs {
                    switch symbol {
                    case _ where stack.count <= i + 2, .postfix:
                        stack[i ... i + 1] = [.symbol(.postfix(symbol.name), [lhs], placeholder)]
                        try collapseStack(from: 0)
                    default:
                        let rhs = stack[i + 2]
                        if rhs.isOperand {
                            if stack.count > i + 3 {
                                let rhs = stack[i + 3]
                                guard !rhs.isOperand, case let .symbol(.infix(op2), _, _) = rhs,
                                    op(symbol.name, takesPrecedenceOver: op2) else {
                                    try collapseStack(from: i + 2)
                                    return
                                }
                            }
                            if symbol.name == ":", case let .symbol(.infix("?"), args, _) = lhs { // ternary
                                stack[i ... i + 2] = [.symbol(.infix("?:"), [args[0], args[1], rhs], placeholder)]
                            } else {
                                stack[i ... i + 2] = [.symbol(.infix(symbol.name), [lhs, rhs], placeholder)]
                            }
                            try collapseStack(from: 0)
                        } else if case let .symbol(symbol2, _, _) = rhs {
                            if case .prefix = symbol2 {
                                try collapseStack(from: i + 2)
                            } else if ["+", "/", "*"].contains(symbol.name) { // Assume infix
                                stack[i + 2] = .symbol(.prefix(symbol2.name), [], placeholder)
                                try collapseStack(from: i + 2)
                            } else { // Assume postfix
                                stack[i + 1] = .symbol(.postfix(symbol.name), [], placeholder)
                                try collapseStack(from: i)
                            }
                        } else if case let .error(error, _) = rhs {
                            throw error
                        }
                    }
                } else if case let .error(error, _) = rhs {
                    throw error
                }
            } else if case let .symbol(symbol, _, _) = lhs {
                // Treat as prefix operator
                if rhs.isOperand {
                    stack[i ... i + 1] = [.symbol(.prefix(symbol.name), [rhs], placeholder)]
                    try collapseStack(from: 0)
                } else if case .symbol = rhs {
                    // Nested prefix operator?
                    try collapseStack(from: i + 1)
                } else if case let .error(error, _) = rhs {
                    throw error
                }
            } else if case let .error(error, _) = lhs {
                throw error
            }
        }

        _ = skipWhitespace()
        var operandPosition = true
        var precededByWhitespace = true
        while !parseDelimiter(delimiters), let expression =
            parseNumericLiteral() ??
            parseIdentifier() ??
            parseOperator() ??
            parseEscapedIdentifier() {

            // Prepare for next iteration
            var followedByWhitespace = skipWhitespace() || isEmpty

            switch expression {
            case let .symbol(.infix(name), _, _):
                switch name {
                case "(":
                    switch stack.last {
                    case let .symbol(.variable(name), _, _)?:
                        var args = [Subexpression]()
                        if first != ")" {
                            repeat {
                                do {
                                    try args.append(parseSubexpression(upTo: [",", ")"]))
                                } catch Expression.Error.unexpectedToken("") {
                                    throw Expression.Error.unexpectedToken(scanCharacter() ?? "")
                                }
                            } while scanCharacter(",")
                        }
                        stack[stack.count - 1] = .symbol(
                            .function(name, arity: .exactly(args.count)), args, placeholder
                        )
                    case let last? where last.isOperand:
                        throw Expression.Error.unexpectedToken("(")
                    default:
                        try stack.append(parseSubexpression(upTo: [")"]))
                    }
                    guard scanCharacter(")") else {
                        throw Expression.Error.missingDelimiter(")")
                    }
                    operandPosition = false
                    followedByWhitespace = skipWhitespace()
                case ",":
                    operandPosition = true
                    if let last = stack.last, !last.isOperand, case let .symbol(.infix(op), _, _) = last {
                        // If previous token was an infix operator, convert it to postfix
                        stack[stack.count - 1] = .symbol(.postfix(op), [], placeholder)
                    }
                    stack.append(expression)
                case "[":
                    guard case let .symbol(.variable(name), _, _)? = stack.last else {
                        throw Expression.Error.unexpectedToken("[")
                    }
                    operandPosition = true
                    do {
                        let index = try parseSubexpression(upTo: [",", "]"])
                        guard scanCharacter("]") else {
                            if scanCharacter(",") {
                                throw Expression.Error.arityMismatch(.array(name))
                            }
                            throw Expression.Error.missingDelimiter("]")
                        }
                        stack[stack.count - 1] = .symbol(.array(name), [index], placeholder)
                    } catch Expression.Error.unexpectedToken("") {
                        guard scanCharacter("]") else {
                            throw Expression.Error.missingDelimiter("]")
                        }
                        throw Expression.Error.unexpectedToken("]")
                    }
                default:
                    operandPosition = true
                    switch (precededByWhitespace, followedByWhitespace) {
                    case (true, true), (false, false):
                        stack.append(expression)
                    case (true, false):
                        stack.append(.symbol(.prefix(name), [], placeholder))
                    case (false, true):
                        stack.append(.symbol(.postfix(name), [], placeholder))
                    }
                }
            case let .symbol(.variable(name), _, _) where !operandPosition:
                operandPosition = true
                stack.append(.symbol(.infix(name), [], placeholder))
            default:
                operandPosition = false
                stack.append(expression)
            }

            // Next iteration
            precededByWhitespace = followedByWhitespace
        }
        // Check for trailing junk
        let start = self
        if !parseDelimiter(delimiters), let junk = scanToEndOfToken() {
            self = start
            throw Expression.Error.unexpectedToken(junk)
        }
        try collapseStack(from: 0)
        switch stack.first {
        case let .error(error, _)?:
            throw error
        case let result?:
            if result.isOperand {
                return result
            }
            throw Expression.Error.unexpectedToken(result.description)
        case nil: // Empty expression
            throw Expression.Error.unexpectedToken("")
        }
    }
}
