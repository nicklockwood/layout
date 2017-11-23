//
//  Expression.swift
//  Expression
//
//  Version 0.8.5
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
    private var root: Subexpression

    /// Function prototype for evaluating an expression
    /// Return nil for an unrecognized symbol, or throw an error if the symbol is recognized
    /// but there is some other problem (e.g. wrong number of arguments for a function)
    public typealias Evaluator = (_ symbol: Symbol, _ args: [Double]) throws -> Double?

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
                return "variable \(name)"
            case let .infix(name):
                return "infix operator \(name)"
            case let .prefix(name):
                return "prefix operator \(name)"
            case let .postfix(name):
                return "postfix operator \(name)"
            case let .function(name, _):
                return "function \(name)()"
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
        case undefinedSymbol(Symbol)

        /// A function was called with the wrong number of arguments (arity)
        case arityMismatch(Symbol)

        /// The human-readable description of the error
        public var description: String {
            switch self {
            case let .message(message):
                return message
            case let .unexpectedToken(string):
                return string.isEmpty ? "Empty expression" : "Unexpected token `\(string)`"
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
                return String(description.first!).uppercased() + String(description.dropFirst()) +
                    " expects \(arity) argument\(arity == 1 ? "" : "s")"
            }
        }

        /// Equatable implementation
        public static func ==(lhs: Error, rhs: Error) -> Bool {
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
    /// - A dictionary of constants for simple static values
    /// - A dictionary of symbols, for implementing custom functions and operators
    /// - A custom evaluator function for more complex symbol processing
    public convenience init(_ expression: String,
                            options: Options = [],
                            constants: [String: Double] = [:],
                            symbols: [Symbol: Symbol.Evaluator] = [:],
                            evaluator: Evaluator? = nil) {
        self.init(
            Expression.parse(expression),
            options: options,
            constants: constants,
            symbols: symbols,
            evaluator: evaluator
        )
    }

    /// Alternative constructor that accepts a pre-parsed expression
    public init(_ expression: ParsedExpression,
                options: Options = [],
                constants: [String: Double] = [:],
                symbols: [Symbol: Symbol.Evaluator] = [:],
                evaluator: Evaluator? = nil) {

        root = expression.root
        let boolSymbols = options.contains(.boolSymbols) ? Expression.boolSymbols : [:]
        var impureSymbols = Dictionary<Symbol, Symbol.Evaluator>()
        var pureSymbols = Dictionary<Symbol, Symbol.Evaluator>()

        // Evaluators
        func symbolEvaluator(for symbol: Expression.Symbol) -> Symbol.Evaluator? {
            if let fn = symbols[symbol] {
                return fn
            } else if boolSymbols.isEmpty, case .infix("?:") = symbol,
                let lhs = symbols[.infix("?")], let rhs = symbols[.infix(":")] {
                return { args in try rhs([lhs([args[0], args[1]]), args[2]]) }
            }
            return nil
        }
        func customEvaluator(for symbol: Symbol, optimizing: Bool) -> Symbol.Evaluator? {
            guard let evaluator = evaluator else {
                return nil
            }
            let fallback: Symbol.Evaluator = {
                guard let fn = defaultEvaluator(for: symbol) else {
                    return errorHandler(for: symbol)
                }
                guard optimizing else {
                    return fn
                }
                return { [unowned self] args in
                    // Rewrite expression to skip custom evaluator
                    pureSymbols[symbol] = customEvaluator(for: symbol, optimizing: false)
                    impureSymbols.removeValue(forKey: symbol)
                    self.root = self.root.optimized(withSymbols: impureSymbols, pureSymbols: pureSymbols)
                    return try fn(args)
                }
            }()
            return { args in
                // Try custom evaluator
                if let value = try evaluator(symbol, args) {
                    return value
                }
                // Special case for ternary
                if args.count == 3, boolSymbols.isEmpty, case .infix("?:") = symbol,
                    let lhs = try evaluator(.infix("?"), [args[0], args[1]]),
                    let value = try evaluator(.infix(":"), [lhs, args[2]]) {
                    return value
                }
                // Try default evaluator
                return try fallback(args)
            }
        }
        func defaultEvaluator(for symbol: Symbol) -> Symbol.Evaluator? {
            // Check default symbols
            return Expression.mathSymbols[symbol] ?? boolSymbols[symbol]
        }
        func errorHandler(for symbol: Symbol) -> Symbol.Evaluator {
            // Check for arity mismatch
            if case let .function(called, arity) = symbol {
                let keys = Set(Expression.mathSymbols.keys).union(boolSymbols.keys).union(symbols.keys)
                for case let .function(name, requiredArity) in keys
                    where name == called && arity != requiredArity {
                    return { _ in throw Error.arityMismatch(.function(called, arity: requiredArity)) }
                }
            }
            // Not found
            return { _ in throw Error.undefinedSymbol(symbol) }
        }

        // Resolve symbols and optimize expression
        let optimize = !options.contains(.noOptimize)
        for symbol in root.symbols {
            if case let .variable(name) = symbol, let value = constants[name] {
                pureSymbols[symbol] = { _ in value }
            } else if let fn = symbolEvaluator(for: symbol) {
                if case .variable = symbol {
                    impureSymbols[symbol] = fn
                } else if options.contains(.pureSymbols) {
                    pureSymbols[symbol] = fn
                } else {
                    impureSymbols[symbol] = fn
                }
            } else if let fn = customEvaluator(for: symbol, optimizing: optimize) {
                impureSymbols[symbol] = fn
            } else {
                pureSymbols[symbol] = defaultEvaluator(for: symbol) ?? errorHandler(for: symbol)
            }
        }
        if !optimize {
            for (symbol, evaluator) in pureSymbols {
                impureSymbols[symbol] = evaluator
            }
            pureSymbols.removeAll()
        }
        root = root.optimized(withSymbols: impureSymbols, pureSymbols: pureSymbols)
    }

    private static var cache = [String: Subexpression]()
    private static let queue = DispatchQueue(label: "com.Expression")

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
        var characters = String.UnicodeScalarView.SubSequence(expression.unicodeScalars)
        let parsedExpression = parse(&characters)

        // Store
        if usingCache {
            queue.async { cache[expression] = parsedExpression.root }
        }
        return parsedExpression
    }

    /// Parse an expression directly from the provided UnicodeScalarView,
    /// stopping when it reaches a token matching the `delimiter` string.
    /// This is convenient if you wish to parse expressions that are nested
    /// inside another string, e.g. for implementing string interpolation.
    /// If no delimiter string is specified, the method will throw an error
    /// if it encounters an unexpected token, but won't consume it
    public static func parse(_ input: inout String.UnicodeScalarView.SubSequence,
                             upTo delimiters: String...) -> ParsedExpression {

        var unicodeScalarView = UnicodeScalarView(input)
        let start = unicodeScalarView
        var subexpression: Subexpression
        do {
            subexpression = try unicodeScalarView.parseSubexpression(upTo: delimiters)
        } catch {
            let expression = String(start.prefix(upTo: unicodeScalarView.startIndex))
            subexpression = .error(error as! Error, expression)
        }
        input = String.UnicodeScalarView.SubSequence(unicodeScalarView)
        return ParsedExpression(root: subexpression)
    }

    /// Clear the expression cache (useful for testing, or in low memory situations)
    public static func clearCache(for expression: String? = nil) {
        queue.async {
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

    // Stand math symbols
    public static let mathSymbols: [Symbol: Symbol.Evaluator] = {
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
    public static let boolSymbols: [Symbol: Symbol.Evaluator] = {
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
    case infix(String)
    case prefix(String)
    case postfix(String)
    case operand(Expression.Symbol, [Subexpression], Expression.Symbol.Evaluator)
    case error(Expression.Error, String)

    func evaluate() throws -> Double {
        switch self {
        case let .literal(value):
            return value
        case let .operand(_, args, fn):
            let argValues = try args.map { try $0.evaluate() }
            return try fn(argValues)
        case let .error(error, _):
            throw error
        case .infix, .prefix, .postfix:
            preconditionFailure()
        }
    }

    var description: String {
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
        case let .operand(symbol, args, _):
            switch symbol {
            case let .prefix(name):
                let arg = args[0]
                let description = "\(arg)"
                switch arg {
                case .operand(.infix, _, _), .operand(.postfix, _, _), .error,
                     .operand where isOperator(name.unicodeScalars.last!)
                         == isOperator(description.unicodeScalars.first!):
                    return "\(name)(\(description))" // Parens required
                case .operand, .literal, .infix, .prefix, .postfix:
                    return "\(name)\(description)" // No parens needed
                }
            case let .postfix(name):
                let arg = args[0]
                let description = "\(arg)"
                switch arg {
                case .operand(.infix, _, _), .operand(.postfix, _, _), .error,
                     .operand where isOperator(name.unicodeScalars.first!)
                         == isOperator(description.unicodeScalars.last!):
                    return "(\(description))\(name)" // Parens required
                case .operand, .literal, .infix, .prefix, .postfix:
                    return "\(description)\(name)" // No parens needed
                }
            case .infix("?:") where args.count == 3:
                return "\(args[0]) ? \(args[1]) : \(args[2])"
            case let .infix(name):
                let lhs = args[0]
                let lhsDescription: String
                switch lhs {
                case let .operand(.infix(opName), _, _) where !op(opName, takesPrecedenceOver: name):
                    lhsDescription = "(\(lhs))"
                default:
                    lhsDescription = "\(lhs)"
                }
                let rhs = args[1]
                let rhsDescription: String
                switch rhs {
                case .operand(.infix, _, _):
                    rhsDescription = "(\(rhs))"
                default:
                    rhsDescription = "\(rhs)"
                }
                return "\(lhsDescription) \(name) \(rhsDescription)"
            case let .variable(name):
                return name
            case let .function(name, _):
                return "\(name)(\(args.map({ $0.description }).joined(separator: ", ")))"
            }
        case let .error(_, expression):
            return expression
        }
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
        case let .operand(symbol, subexpressions, _):
            var symbols = Set([symbol])
            for subexpression in subexpressions {
                symbols.formUnion(subexpression.symbols)
            }
            return symbols
        }
    }

    func optimized(withSymbols impureSymbols: [Expression.Symbol: Expression.Symbol.Evaluator],
                   pureSymbols: [Expression.Symbol: Expression.Symbol.Evaluator]) -> Subexpression {

        guard case .operand(let symbol, var args, _) = self else {
            return self
        }
        args = args.map { $0.optimized(withSymbols: impureSymbols, pureSymbols: pureSymbols) }
        guard let fn = pureSymbols[symbol] else {
            return .operand(symbol, args, impureSymbols[symbol]!)
        }
        var argValues = [Double]()
        for arg in args {
            guard case let .literal(value) = arg else {
                return .operand(symbol, args, fn)
            }
            argValues.append(value)
        }
        guard let result = try? fn(argValues) else {
            return .operand(symbol, args, fn)
        }
        return .literal(result)
    }
}

private let placeholder: Expression.Symbol.Evaluator = { _ in
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
    if "/=­-+!*%<>&|^~?:".unicodeScalars.contains(char) {
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

// Workaround for horribly slow String.UnicodeScalarView.Subsequence perf

struct UnicodeScalarView {
    public typealias Index = String.UnicodeScalarView.Index

    private let characters: String.UnicodeScalarView
    public private(set) var startIndex: Index
    public private(set) var endIndex: Index

    public init(_ unicodeScalars: String.UnicodeScalarView) {
        characters = unicodeScalars
        startIndex = characters.startIndex
        endIndex = characters.endIndex
    }

    public init(_ unicodeScalars: String.UnicodeScalarView.SubSequence) {
        self.init(String.UnicodeScalarView(unicodeScalars))
    }

    public init(_ string: String) {
        self.init(string.unicodeScalars)
    }

    public var first: UnicodeScalar? {
        return isEmpty ? nil : characters[startIndex]
    }

    public var count: Int {
        return characters.distance(from: startIndex, to: endIndex)
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

    public func dropFirst() -> UnicodeScalarView {
        var view = UnicodeScalarView(characters)
        view.startIndex = characters.index(after: startIndex)
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

    /// Will crash if n > remaining char count
    public mutating func removeFirst(_ n: Int) {
        startIndex = characters.index(startIndex, offsetBy: n)
    }

    /// Will crash if collection is empty
    @discardableResult
    public mutating func removeFirst() -> UnicodeScalar {
        let oldIndex = startIndex
        startIndex = characters.index(after: startIndex)
        return characters[oldIndex]
    }

    /// Returns the remaining characters
    fileprivate var unicodeScalars: String.UnicodeScalarView.SubSequence {
        return characters[startIndex ..< endIndex]
    }
}

typealias _UnicodeScalarView = UnicodeScalarView
extension String {
    init(_ unicodeScalarView: _UnicodeScalarView) {
        self.init(unicodeScalarView.unicodeScalars)
    }
}

extension String.UnicodeScalarView {
    init(_ unicodeScalarView: _UnicodeScalarView) {
        self.init(unicodeScalarView.unicodeScalars)
    }
}

extension String.UnicodeScalarView.SubSequence {
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

    mutating func parseDelimiter(_ delimiters: [String]) -> Subexpression? {
        outer: for delimiter in delimiters {
            let start = self
            for char in delimiter.unicodeScalars {
                guard scanCharacter(char) else {
                    self = start
                    continue outer
                }
            }
            self = start
            return .error(.unexpectedToken(delimiter), delimiter)
        }
        return nil
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
            return .error(.unexpectedToken(number), number)
        }
        return .literal(value)
    }

    mutating func parseOperator() -> Subexpression? {
        if let op = scanCharacter({ "(),".unicodeScalars.contains($0) }) {
            return .infix(op)
        }
        if let op = scanCharacters({ isOperator($0) || $0 == "." }) {
            return .infix(op) // assume infix, will determine later
        }
        return nil
    }

    mutating func parseIdentifier() -> Subexpression? {

        func isHead(_ c: UnicodeScalar) -> Bool {
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
            var start = self
            var identifier = ""
            if scanCharacter(".") {
                identifier = "."
            } else if let head = scanCharacter(isHead) {
                identifier = head
                start = self
                if scanCharacter(".") {
                    identifier.append(".")
                }
            } else {
                return nil
            }
            while let tail = scanCharacters(isTail) {
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
            }
            return identifier
        }

        guard let identifier = scanIdentifier() else {
            return nil
        }
        return .operand(.variable(identifier), [], placeholder)
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
                case "\0":
                    string += "\0"
                case "t":
                    string += "\t"
                case "n":
                    string += "\n"
                case "r":
                    string += "\r"
                case "u":
                    guard scanCharacter("{"),
                        let hex = scanCharacters({
                            switch $0 {
                            case "0" ... "9", "A" ... "F", "a" ... "f":
                                return true
                            default:
                                return false
                            }
                        }),
                        scanCharacter("}"),
                        let codepoint = Int(hex, radix: 16),
                        let c = UnicodeScalar(codepoint) else {
                        return .error(.unexpectedToken(string), string)
                    }
                    string.append(Character(c))
                default:
                    string.append(Character(c))
                }
            }
        }
        guard scanCharacter(delimiter) else {
            return .error(.unexpectedToken(string), string)
        }
        return .operand(.variable(string + String(delimiter)), [], placeholder)
    }

    mutating func parseSubexpression(upTo delimiters: [String]) throws -> Subexpression {
        var stack: [Subexpression] = []
        var scopes: [[Subexpression]] = []

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
                    stack[i ... i + 1] = [.operand(.prefix(name), [rhs], placeholder)]
                    try collapseStack(from: 0)
                case .prefix, .infix, .postfix:
                    // nested prefix operator?
                    try collapseStack(from: i + 1)
                case let .error(error, _):
                    throw error
                }
            case .literal where stack.count <= i + 1:
                throw Expression.Error.unexpectedToken("\(lhs)")
            case let .operand(symbol, _, _) where stack.count <= i + 1:
                throw Expression.Error.unexpectedToken(symbol.name)
            case .literal, .operand:
                let rhs = stack[i + 1]
                switch rhs {
                case .literal, .operand:
                    guard case let .operand(.postfix(op), args, _) = lhs, let arg = args.first else {
                        // cannot follow an operand
                        throw Expression.Error.unexpectedToken("\(rhs)")
                    }
                    // assume prefix operator was actually an infix operator
                    stack[i] = arg
                    stack.insert(.infix(op), at: i + 1)
                    try collapseStack(from: i)
                case let .postfix(op1):
                    stack[i ... i + 1] = [.operand(.postfix(op1), [lhs], placeholder)]
                    try collapseStack(from: 0)
                case let .infix(op1), let .prefix(op1): // treat as infix
                    guard stack.count > i + 2 else { // treat as postfix
                        stack[i ... i + 1] = [.operand(.postfix(op1), [lhs], placeholder)]
                        try collapseStack(from: 0)
                        return
                    }
                    let rhs = stack[i + 2]
                    switch rhs {
                    case .prefix:
                        try collapseStack(from: i + 2)
                    case .infix, .postfix: // assume we're actually postfix
                        stack[i + 1] = .postfix(op1)
                        try collapseStack(from: i)
                    case .literal where stack.count > i + 3, .operand where stack.count > i + 3:
                        if case let .infix(op2) = stack[i + 3], op(op1, takesPrecedenceOver: op2) {
                            fallthrough
                        }
                        try collapseStack(from: i + 2)
                    case .literal, .operand:
                        if op1 == ":", case let .operand(.infix("?"), args, placeholder) = lhs { // ternary
                            stack[i ... i + 2] = [.operand(.infix("?:"), [args[0], args[1], rhs], placeholder)]
                        } else {
                            stack[i ... i + 2] = [.operand(.infix(op1), [lhs, rhs], placeholder)]
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

        _ = skipWhitespace()
        var operandPosition = true
        var precededByWhitespace = true
        loop: while let expression =
            parseDelimiter(delimiters) ??
            parseNumericLiteral() ??
            parseIdentifier() ??
            parseOperator() ??
            parseEscapedIdentifier() {

            // prepare for next iteration
            let followedByWhitespace = skipWhitespace() || isEmpty

            switch expression {
            case let .error(.unexpectedToken(delimiter), _) where delimiters.contains(delimiter):
                break loop
            case .infix("("):
                operandPosition = true
                scopes.append(stack)
                stack = []
            case .infix(")"):
                operandPosition = false
                if let previous = stack.last {
                    switch previous {
                    case let .infix(op), let .prefix(op):
                        stack[stack.count - 1] = .postfix(op)
                    default:
                        break
                    }
                }
                try collapseStack(from: 0)
                guard var oldStack = scopes.last else {
                    throw Expression.Error.unexpectedToken(")")
                }
                scopes.removeLast()
                if let previous = oldStack.last {
                    switch previous {
                    case let .operand(.variable(name), _, _):
                        // function call
                        oldStack.removeLast()
                        if stack.count > 0 {
                            // unwrap comma-delimited expression
                            while case let .operand(.infix(","), args, _) = stack.first! {
                                stack = args + stack.dropFirst()
                            }
                        }
                        stack = [.operand(.function(name, arity: stack.count), stack, placeholder)]
                    case .operand(.function, _, _):
                        throw Expression.Error.unexpectedToken("(")
                    default:
                        break
                    }
                }
                stack = oldStack + stack
            case .infix(","):
                operandPosition = true
                if let previous = stack.last, case let .infix(op) = previous {
                    stack[stack.count - 1] = .postfix(op)
                }
                stack.append(expression)
            case let .infix(name):
                operandPosition = true
                switch (precededByWhitespace, followedByWhitespace) {
                case (true, true), (false, false):
                    stack.append(expression)
                case (true, false):
                    stack.append(.prefix(name))
                case (false, true):
                    stack.append(.postfix(name))
                }
            case let .operand(.variable(name), _, _):
                if operandPosition {
                    fallthrough
                }
                operandPosition = true
                stack.append(.infix(name))
            default:
                operandPosition = false
                stack.append(expression)
            }

            // next iteration
            precededByWhitespace = followedByWhitespace
        }
        // Check for trailing junk
        let start = self
        if parseDelimiter(delimiters) == nil, let junk = scanCharacters({
            switch $0 {
            case " ", "\t", "\n", "\r":
                return false
            default:
                return true
            }
        }) {
            self = start
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
        let result = stack[0]
        switch result {
        case let .prefix(symbol), let .postfix(symbol), let .infix(symbol):
            throw Expression.Error.unexpectedToken(symbol)
        case let .error(error, _):
            throw error
        case .literal, .operand:
            return result
        }
    }
}
