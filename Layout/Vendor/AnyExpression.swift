//
//  AnyExpression.swift
//  Expression
//
//  Version 0.11.3
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
        // Options
        let usePureSymbols = options.contains(.pureSymbols)
        let useBoolSymbols = options.contains(.boolSymbols)

        self.init(
            expression,
            impureSymbols: { symbol in
                switch symbol {
                case let .variable(name), let .array(name):
                    if constants[name] != nil {
                        return nil
                    } else if let fn = symbols[symbol] {
                        return fn // Variables and array symbols are never pure
                    }
                default:
                    if let fn = symbols[symbol] {
                        return usePureSymbols ? nil : fn
                    }
                }
                if let evaluator = evaluator {
                    switch symbol {
                    case .variable("nil"), .infix("??"),
                         _ where Expression.mathSymbols[symbol] != nil,
                         _ where useBoolSymbols && Expression.boolSymbols[symbol] != nil:
                        return nil // Standard library
                    case let .variable(name) where constants[name] != nil ||
                            name.first == "\"" || (name.first == "'" && name.last == "'"):
                        return nil // String
                    default:
                        return { args in
                            guard let value = try evaluator(symbol, args) else {
                                throw Error.undefinedSymbol(symbol)
                            }
                            return value
                        }
                    }
                }
                return nil
            },
            pureSymbols: { symbol in
                switch symbol {
                case let .variable(name):
                    if let value = constants[name] {
                        return { _ in value }
                    }
                case let .array(name):
                    if let array = constants[name] as? [Any] {
                        return { args in
                            guard let number = args[0] as? NSNumber else {
                                try AnyExpression.throwTypeMismatch(symbol, args)
                            }
                            guard let index = Int(exactly: number), array.indices.contains(index) else {
                                throw Error.arrayBounds(symbol, Double(truncating: number))
                            }
                            return array[index]
                        }
                    }
                default:
                    if usePureSymbols {
                        return symbols[symbol]
                    }
                }
                return nil
            }
        )
    }

    /// Alternative constructor for advanced usage
    /// Allows for dynamic symbol lookup or generation without any performance overhead
    /// Note that standard library symbols are all enabled by default - to disable them
    /// return `{ _ in throw AnyExpression.Error.undefinedSymbol(symbol) }` from your lookup function
    public init(
        _ expression: ParsedExpression,
        impureSymbols: (Symbol) -> SymbolEvaluator?,
        pureSymbols: (Symbol) -> SymbolEvaluator?
    ) {
        let mask = (-Double.nan).bitPattern
        let indexOffset = 4

        func bitPattern(for index: Int) -> UInt64 {
            assert(index > -indexOffset)
            return UInt64(index + indexOffset) | mask
        }

        let nilBits = bitPattern(for: -1)
        let falseBits = bitPattern(for: -2)
        let trueBits = bitPattern(for: -3)

        var values = [Any]()
        func store(_ value: Any) -> Double {
            switch value {
            case let doubleValue as Double:
                return doubleValue
            case let boolValue as Bool:
                return Double(bitPattern: boolValue ? trueBits : falseBits)
            case let floatValue as Float:
                return Double(floatValue)
            case is Int, is UInt, is Int32, is UInt32:
                return Double(truncating: value as! NSNumber)
            case let uintValue as UInt64:
                if uintValue <= 9007199254740992 as UInt64 {
                    return Double(uintValue)
                }
            case let intValue as Int64:
                if intValue <= 9007199254740992 as Int64, intValue >= -9223372036854775808 as Int64 {
                    return Double(intValue)
                }
            case let numberValue as NSNumber:
                // Hack to avoid losing type info for UIFont.Weight, etc
                if "\(value)".contains("rawValue") {
                    break
                }
                return Double(truncating: numberValue)
            case _ where AnyExpression.isNil(value):
                return Double(bitPattern: nilBits)
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
                case nilBits:
                    return nil as Any? as Any
                case trueBits:
                    return true
                case falseBits:
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

        // Set description based on the parsed expression, prior to
        // peforming optimizations. This avoids issues with inlined
        // constants and string literals being converted to `nan`
        description = expression.description

        // Build Expression
        let expression = Expression(
            expression,
            impureSymbols: { symbol in
                impureSymbols(symbol).map { fn in
                    switch symbol {
                    case .variable, .function(_, arity: 0):
                        return { _ in try store(fn([])) }
                    default:
                        return { try store(fn($0.map(load))) }
                    }
                }
            },
            pureSymbols: { symbol in
                if let fn = pureSymbols(symbol) {
                    switch symbol {
                    case .variable, .function(_, arity: 0):
                        do {
                            let value = try store(fn([]))
                            return { _ in value }
                        } catch {
                            return { _ in throw error }
                        }
                    default:
                        return { try store(fn($0.map(load))) }
                    }
                } else if let fn = Expression.mathSymbols[symbol] {
                    switch symbol {
                    case .infix("+"):
                        return { args in
                            switch (load(args[0]), load(args[1])) {
                            case let (lhs as String, rhs):
                                return try store("\(lhs)\(AnyExpression.stringify(rhs))")
                            case let (lhs, rhs as String):
                                return try store("\(AnyExpression.stringify(lhs))\(rhs)")
                            case let (lhs as Double, rhs as Double):
                                return lhs + rhs
                            case let (lhs as NSNumber, rhs as NSNumber):
                                return Double(truncating: lhs) + Double(truncating: rhs)
                            case let (lhs, rhs):
                                _ = try AnyExpression.unwrap(lhs)
                                _ = try AnyExpression.unwrap(rhs)
                                try AnyExpression.throwTypeMismatch(symbol, [lhs, rhs])
                            }
                        }
                    case .variable, .function(_, arity: 0):
                        return fn
                    default:
                        return { args in
                            // We potentially lose precision by converting all numbers to doubles
                            // TODO: find alternative approach that doesn't lose precision
                            try fn(args.map {
                                guard let doubleValue = loadNumber($0) else {
                                    _ = try AnyExpression.unwrap(load($0))
                                    try AnyExpression.throwTypeMismatch(symbol, args.map(load))
                                }
                                return doubleValue
                            })
                        }
                    }
                } else if let fn = Expression.boolSymbols[symbol] {
                    switch symbol {
                    case .variable("false"):
                        return { _ in Double(bitPattern: falseBits) }
                    case .variable("true"):
                        return { _ in Double(bitPattern: trueBits) }
                    case .infix("=="):
                        return { Double(bitPattern: equalArgs($0[0], $0[1]) ? trueBits : falseBits) }
                    case .infix("!="):
                        return { Double(bitPattern: equalArgs($0[0], $0[1]) ? falseBits : trueBits) }
                    case .infix("?:"):
                        return { args in
                            guard args.count == 3 else {
                                throw Error.undefinedSymbol(symbol)
                            }
                            if let number = loadNumber(args[0]) {
                                return number != 0 ? args[1] : args[2]
                            }
                            try AnyExpression.throwTypeMismatch(symbol, args.map(load))
                        }
                    default:
                        return { args in
                            // TODO: find alternative approach that doesn't lose precision
                            try store(fn(args.map {
                                guard let doubleValue = loadNumber($0) else {
                                    _ = try AnyExpression.unwrap(load($0))
                                    try AnyExpression.throwTypeMismatch(symbol, args.map(load))
                                }
                                return doubleValue
                            }) != 0)
                        }
                    }
                } else {
                    switch symbol {
                    case .variable("nil"):
                        return { _ in Double(bitPattern: nilBits) }
                    case .infix("??"):
                        return { args in
                            let lhs = load(args[0])
                            return AnyExpression.isNil(lhs) ? args[1] : args[0]
                        }
                    case let .variable(name):
                        guard name.count >= 2, "'\"".contains(name.first!), name.last == name.first else {
                            return nil
                        }
                        let stringRef = store(String(name.dropFirst().dropLast()))
                        return { _ in stringRef }
                    default:
                        return nil
                    }
                }
            }
        )

        // These are constant values that won't change between evaluations
        // and won't be re-stored, so must not be cleared
        let literals = values

        evaluator = {
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

    // Throw a type mismatch error
    static func throwTypeMismatch(_ symbol: Symbol, _ args: [Any]) throws -> Never {
        throw Error.message("\(symbol) cannot be used with arguments of type (\(args.map { "\(type(of: $0))" }.joined(separator: ", ")))")
    }

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
}

extension Optional: _Optional {
    fileprivate var value: Any? { return self }
}

extension ImplicitlyUnwrappedOptional: _Optional {
    fileprivate var value: Any? { return self }
}
