//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

private let mask: UInt64 = 0b11111111_11111000_00000000_00000000_00000000_00000000_00000000_00000000

// Version of Expression that works with any value type
struct AnyExpression: CustomStringConvertible {
    let evaluate: () throws -> Any
    let symbols: Set<Symbol>
    let description: String

    typealias Options = Expression.Options
    typealias Error = Expression.Error
    typealias Symbol = Expression.Symbol
    typealias Evaluator = (_ symbol: Symbol, _ args: [Any]) throws -> Any?
    typealias SymbolEvaluator = (_ args: [Any]) throws -> Any

    init(_ expression: String,
         options: Options = .boolSymbols,
         constants: [String: Any] = [:],
         symbols: [Symbol: SymbolEvaluator] = [:],
         evaluator: Evaluator? = nil) {
        self.init(
            Expression.parse(expression),
            options: options,
            constants: constants,
            symbols: symbols,
            evaluator: evaluator
        )
    }

    init(_ expression: ParsedExpression,
         options: Options = .boolSymbols,
         constants: [String: Any] = [:],
         symbols: [Symbol: SymbolEvaluator] = [:],
         evaluator: Evaluator? = nil) {
        var values = [Any]()
        func store(_ value: Any) throws -> Double {
            if let value = (value as? NSNumber).map({ Double($0) }) {
                if value.bitPattern & mask == mask {
                    // Value is NaN
                    return Double(bitPattern: mask)
                }
                return value
            }
            if let lhs = value as? AnyHashable {
                if let index = values.index(where: {
                    if let rhs = $0 as? AnyHashable {
                        return lhs == rhs
                    }
                    return false
                }) {
                    return Double(bitPattern: UInt64(index + 1) | mask)
                }
            } else if isNil(value), let index = values.index(where: { isNil($0) }) {
                return Double(bitPattern: UInt64(index + 1) | mask)
            }
            values.append(value)
            return Double(bitPattern: UInt64(values.count) | mask)
        }
        func load(_ arg: Double) -> Any {
            let bits = arg.bitPattern
            if bits & mask == mask {
                let index = Int(bits ^ mask) - 1
                if index < values.count {
                    return values[index]
                }
            }
            return arg
        }

        // Handle string literals and constants
        var numericConstants = [String: Double]()
        do {
            for symbol in expression.symbols {
                if case let .variable(name) = symbol {
                    if let value = constants[name] {
                        numericConstants[name] = try store(value)
                        continue
                    }
                    if name == "nil" {
                        let null: Any? = nil
                        numericConstants["nil"] = try store(null as Any)
                        continue
                    }
                    var chars = name.characters
                    if chars.count >= 2, let first = chars.first, let last = chars.last,
                        "'\"".characters.contains(first), last == first {
                        chars.removeFirst()
                        chars.removeLast()
                        numericConstants[name] = try store(String(chars))
                    }
                }
            }
        } catch {
            evaluate = { throw error }
            self.symbols = []
            description = expression.description
            return
        }

        // These are constant values that won't change between evaluations
        // and won't be re-stored, so must not be cleared
        let literals = values

        // Convert symbols
        var numericSymbols = [Symbol: ([Double]) throws -> Double]()
        for (symbol, closure) in symbols {
            numericSymbols[symbol] = { args in
                let anyArgs = args.map(load)
                let value = try closure(anyArgs)
                return try store(value)
            }
        }

        let expression = Expression(expression,
                                    options: options,
                                    constants: numericConstants,
                                    symbols: numericSymbols) { symbol, args in
            let anyArgs = args.map(load)
            if let value = try evaluator?(symbol, anyArgs) {
                return try store(value)
            }
            if case .infix("??") = symbol {
                guard isOptional(anyArgs[0]) else {
                    throw Error.message("left hand argument of ?? operator must be optional")
                }
                return isNil(anyArgs[0]) ? args[1] : args[0]
            }
            if let doubleArgs = anyArgs as? [Double], doubleArgs == args {
                return nil // Fall back to default implementation
            }
            switch symbol {
            case .infix("+"):
                return try store("\(unwrap(anyArgs[0]))\(unwrap(anyArgs[1]))")
            case .infix("=="):
                return args[0].bitPattern == args[1].bitPattern ? 1 : 0
            case .infix("!="):
                return args[0].bitPattern != args[1].bitPattern ? 1 : 0
            case .infix("?:") where anyArgs[0] is Double:
                return nil // Fall back to default implementation
            default:
                throw Error.message("\(symbol) cannot be used with arguments of type \(anyArgs.map { type(of: $0) })")
            }
        }
        evaluate = {
            defer { values = literals }
            return try load(expression.evaluate())
        }
        self.symbols = expression.symbols
        description = expression.description
    }
}
