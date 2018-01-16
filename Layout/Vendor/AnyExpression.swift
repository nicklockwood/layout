//
//  AnyExpression.swift
//  Expression
//
//  Version 0.11.2
//
//  Created by Nick Lockwood on 18/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
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

/// Wrapper for Expression that works with any type of value
public struct AnyExpression: CustomStringConvertible {
    private let expression: Expression
    private let evaluator: () throws -> Any

    /// Function prototype for evaluating an expression
    /// Return nil for an unrecognized symbol, or throw an error if the symbol is recognized
    /// but there is some other problem (e.g. wrong number or type of arguments)
    public typealias Evaluator = (_ symbol: Symbol, _ args: [Any]) throws -> Any?

    /// Evaluator for individual symbols
    public typealias SymbolEvaluator = (_ args: [Any]) throws -> Any

    /// Symbols that make up an expression
    public typealias Symbol = Expression.Symbol

    /// Runtime error when parsing or evaluating an expression
    public typealias Error = Expression.Error

    /// Options for configuring an expression
    public typealias Options = Expression.Options

    /// Creates an Expression object from a string
    /// Optionally accepts some or all of:
    /// - A set of options for configuring expression behavior
    /// - A dictionary of constants for simple static values (including arrays)
    /// - A dictionary of symbols, for implementing custom functions and operators
    /// - A custom evaluator function for more complex symbol processing
    public init(
        _ expression: String,
        options: Options = .boolSymbols,
        constants: [String: Any] = [:],
        symbols: [Symbol: SymbolEvaluator] = [:],
        evaluator: Evaluator? = nil
    ) {
        self.init(
            Expression.parse(expression),
            options: options,
            constants: constants,
            symbols: symbols,
            evaluator: evaluator
        )
    }

    /// Alternative constructor that accepts a pre-parsed expression
    public init(
        _ expression: ParsedExpression,
        options: Options = .boolSymbols,
        constants: [String: Any] = [:],
        symbols: [Symbol: SymbolEvaluator] = [:],
        evaluator: Evaluator? = nil
    ) {
        let mask = (-Double.nan).bitPattern
        let indexOffset = 4

        func bitPattern(for index: Int) -> UInt64 {
            assert(index > -indexOffset)
            return UInt64(index + indexOffset) | mask
        }

        let nilIndex = bitPattern(for: -1)
        let falseIndex = bitPattern(for: -2)
        let trueIndex = bitPattern(for: -3)

        var values = [Any]()
        func store(_ value: Any) -> Double {
            switch value {
            case let bool as Bool:
                return Double(bitPattern: bool ? trueIndex : falseIndex)
            case let doubleValue as Double:
                return doubleValue
            case let floatValue as Float:
                return Double(floatValue)
            case is Int, is UInt, is Int32, is UInt32:
                return Double(truncating: value as! NSNumber)
            case let uintValue as UInt64:
                if uintValue <= 9007199254740992 as UInt64 {
                    return Double(uintValue)
                }
            case let intValue as Int64:
                if intValue <= 9007199254740992 as Int64,
                    intValue >= -9223372036854775808 as Int64 {
                    return Double(intValue)
                }
            case let numberValue as NSNumber:
                // Hack to avoid losing type info for UIFont.Weight, etc
                if "\(value)".contains("rawValue") {
                    break
                }
                return Double(truncating: numberValue)
            case _ where AnyExpression.isNil(value):
                return Double(bitPattern: nilIndex)
            default:
                break
            }
            values.append(value)
            return Double(bitPattern: bitPattern(for: values.count - 1))
        }
        func loadIfStored(_ arg: Double) -> Any? {
            let bits = arg.bitPattern
            if bits & mask == mask {
                switch bits {
                case nilIndex:
                    return nil as Any? as Any
                case trueIndex:
                    return true
                case falseIndex:
                    return false
                default:
                    let index = Int(bits ^ mask) - indexOffset
                    if values.indices.contains(index) {
                        return values[index]
                    }
                }
            }
            return nil
        }
        func load(_ arg: Double) -> Any {
            return loadIfStored(arg) ?? arg
        }
        func loadNumber(_ arg: Double) -> Double? {
            return loadIfStored(arg).map { ($0 as? NSNumber).map { Double(truncating: $0) } } ?? arg
        }
        func equalArgs(_ lhs: Double, _ rhs: Double) -> Bool {
            let lhs = load(lhs), rhs = load(rhs)
            switch (lhs, rhs) {
            case let (lhs as Double, rhs as Double):
                return lhs == rhs
            case let (lhs as String, rhs as String):
                return lhs == rhs
            case let (lhs as AnyHashable, rhs as AnyHashable):
                return lhs == rhs
            case let (lhs as [AnyHashable], rhs as [AnyHashable]):
                return lhs == rhs
            case let (lhs, rhs) where AnyExpression.isNil(lhs) && AnyExpression.isNil(rhs):
                return true
            default:
                // TODO: should comparing non-equatable values be an error?
                return false
            }
        }
        func throwTypeMismatch(_ symbol: Symbol, _ anyArgs: [Any]) throws -> Never {
            throw Error.message("\(symbol) cannot be used with arguments of type (\(anyArgs.map { "\(type(of: $0))" }.joined(separator: ", ")))")
        }

        // Options
        let usePureSymbols = options.contains(.pureSymbols)
        let boolSymbols = options.contains(.boolSymbols) ? Expression.boolSymbols : [:]

        // Handle string literals and constants
        var numericConstants = [String: Double]()
        var arrayConstants = [String: [Double]]()
        var pureSymbols = [Symbol: ([Double]) throws -> Double]()
        var impureSymbols = [Symbol: ([Any]) throws -> Any]()
        for symbol in expression.symbols {
            if case let .variable(name) = symbol, let value = constants[name] {
                numericConstants[name] = store(value)
            } else if let fn = symbols[symbol] {
                if usePureSymbols {
                    pureSymbols[symbol] = { args in
                        try store(fn(args.map(load)))
                    }
                } else {
                    impureSymbols[symbol] = fn
                }
            } else if let fn = Expression.mathSymbols[symbol] {
                if case .infix("+") = symbol {
                    pureSymbols[symbol] = { args in
                        switch try (AnyExpression.unwrap(load(args[0])), AnyExpression.unwrap(load(args[1]))) {
                        case let (lhs as String, rhs):
                            return try store("\(lhs)\(AnyExpression.stringify(rhs))")
                        case let (lhs, rhs as String):
                            return try store("\(AnyExpression.stringify(lhs))\(rhs)")
                        case let (lhs as Double, rhs as Double):
                            return lhs + rhs
                        case let (lhs as NSNumber, rhs as NSNumber):
                            return Double(truncating: lhs) + Double(truncating: rhs)
                        case let (lhs, rhs):
                            try throwTypeMismatch(.infix("+"), [lhs, rhs])
                        }
                    }
                } else {
                    pureSymbols[symbol] = { args in
                        // We potentially lose precision by converting all numbers to doubles
                        // TODO: find alternative approach that doesn't lose precision
                        try fn(args.map {
                            guard let doubleValue = loadNumber($0) else {
                                _ = try AnyExpression.unwrap(load($0))
                                try throwTypeMismatch(symbol, args.map(load))
                            }
                            return doubleValue
                        })
                    }
                }
            } else if let fn = boolSymbols[symbol] {
                switch symbol {
                case .variable("false"):
                    numericConstants["false"] = store(false)
                case .variable("true"):
                    numericConstants["true"] = store(true)
                case .infix("=="):
                    pureSymbols[symbol] = { args in store(equalArgs(args[0], args[1])) }
                case .infix("!="):
                    pureSymbols[symbol] = { args in store(!equalArgs(args[0], args[1])) }
                case .infix("?:"):
                    pureSymbols[symbol] = { args in
                        guard args.count == 3 else {
                            throw Error.undefinedSymbol(symbol)
                        }
                        if let number = loadNumber(args[0]) {
                            return number != 0 ? args[1] : args[2]
                        }
                        try throwTypeMismatch(symbol, args.map(load))
                    }
                default:
                    pureSymbols[symbol] = { args in
                        // TODO: find alternative approach that doesn't lose precision
                        try store(fn(args.map {
                            guard let doubleValue = loadNumber($0) else {
                                _ = try AnyExpression.unwrap(load($0))
                                try throwTypeMismatch(symbol, args.map(load))
                            }
                            return doubleValue
                        }) != 0)
                    }
                }
            } else {
                switch symbol {
                case .variable("nil"):
                    numericConstants["nil"] = store(nil as Any? as Any)
                case let .variable(name):
                    if name.count >= 2, "'\"".contains(name.first!), name.last == name.first {
                        numericConstants[name] = store(String(name.dropFirst().dropLast()))
                    }
                case let .array(name):
                    if let array = constants[name] as? [Any] {
                        arrayConstants[name] = array.map { store($0) }
                    }
                case .infix("??"):
                    pureSymbols[symbol] = { args in
                        let lhs = load(args[0])
                        return AnyExpression.isNil(lhs) ? args[1] : args[0]
                    }
                default:
                    break
                }
            }
        }

        // Set description based on the parsed expression, prior to
        // peforming optimizations. This avoids issues with inlined
        // constants and string literals being converted to `nan`
        description = expression.description

        // Build Evaluator
        let needsEvaluator = evaluator != nil || !impureSymbols.isEmpty
        let numericEvaluator: Expression.Evaluator? = needsEvaluator ? { symbol, args in
            let anyArgs = args.map(load)
            if let value = try impureSymbols[symbol]?(anyArgs) ?? evaluator?(symbol, anyArgs) {
                return store(value)
            }
            return nil
        } : nil

        // Build Expression
        let expression = Expression(
            expression,
            options: options.subtracting(.boolSymbols).union([.pureSymbols, .noDeferredOptimize]),
            constants: numericConstants,
            arrays: arrayConstants,
            symbols: pureSymbols,
            evaluator: numericEvaluator
        )

        // These are constant values that won't change between evaluations
        // and won't be re-stored, so must not be cleared
        let literals = values

        self.evaluator = {
            defer { values = literals }
            let value = try expression.evaluate()
            return load(value)
        }
        self.expression = expression
    }

    /// Evaluate the expression
    public func evaluate<T>() throws -> T {
        guard let value: T = try AnyExpression.cast(evaluator()) else {
            throw Error.message("Unexpected nil return value")
        }
        return value
    }

    /// All symbols used in the expression
    public var symbols: Set<Symbol> {
        return expression.symbols
    }

    /// Returns the optmized, pretty-printed expression if it was valid
    /// Otherwise, returns the original (invalid) expression string
    public let description: String
}

// Private API
private extension AnyExpression {

    // Convert any object to a string
    static func stringify(_ value: Any) throws -> String {
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
        case let value:
            return "\(value)"
        }
    }

    // Cast a value
    static func cast<T>(_ anyValue: Any) throws -> T? {
        if let value = anyValue as? T {
            return value
        }
        switch T.self {
        case let type as _Optional.Type where anyValue is NSNull:
            return type.nullValue as? T
        case is Double.Type, is Optional<Double>.Type:
            if let value = anyValue as? NSNumber {
                return Double(truncating: value) as? T
            }
        case is Int.Type, is Optional<Int>.Type:
            if let value = anyValue as? NSNumber {
                return Int(truncating: value) as? T
            }
        case is Bool.Type, is Optional<Bool>.Type:
            if let value = anyValue as? NSNumber {
                return (Double(truncating: value) != 0) as? T
            }
        case is String.Type:
            return try stringify(anyValue) as? T
        default:
            break
        }
        if isNil(anyValue) {
            return nil
        }
        throw AnyExpression.Error.message("Return type mismatch: \(type(of: anyValue)) is not compatible with \(T.self)")
    }

    // Unwraps a potentially optional value or throws if nil
    static func unwrap(_ value: Any) throws -> Any {
        switch value {
        case let optional as _Optional:
            guard let value = optional.value else {
                fallthrough
            }
            return try unwrap(value)
        case is NSNull:
            throw AnyExpression.Error.message("Unexpected nil value")
        default:
            return value
        }
    }

    // Test if a value is nil
    static func isNil(_ value: Any) -> Bool {
        if let optional = value as? _Optional {
            guard let value = optional.value else {
                return true
            }
            return isNil(value)
        }
        return value is NSNull
    }
}

// Used to test if a value is Optional
private protocol _Optional {
    var value: Any? { get }
    static var nullValue: Any { get }
}

extension Optional: _Optional {
    fileprivate var value: Any? { return self }
    static var nullValue: Any { return none as Any }
}

extension ImplicitlyUnwrappedOptional: _Optional {
    fileprivate var value: Any? { return self }
    static var nullValue: Any { return none as Any }
}
