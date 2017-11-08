//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

private let mask = (-Double.nan).bitPattern

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

    init(
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

    init(
        _ expression: ParsedExpression,
        options: Options = .boolSymbols,
        constants: [String: Any] = [:],
        symbols: [Symbol: SymbolEvaluator] = [:],
        evaluator: Evaluator? = nil
    ) {
        var values = [Any]()
        func store(_ value: Any) -> Double {
            switch value {
            case let doubleValue as Double:
                return doubleValue
            case let floatValue as Float:
                return Double(floatValue)
            case is Bool, is CGFloat, is Int, is UInt, is Int32, is UInt32:
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
                if "\(value)".contains("rawValue") { // Hack to avoid losing type info for UIFont.Weight, etc
                    break
                }
                // TODO: implement strict bool handling instead of treating as a number
                return Double(truncating: numberValue)
            default:
                break
            }
            if isNil(value), let index = values.index(where: { isNil($0) }) {
                return Double(bitPattern: UInt64(index + 1) | mask)
            } else if let lhs = value as? AnyHashable {
                if let index = values.index(where: { $0 as? AnyHashable == lhs }) {
                    return Double(bitPattern: UInt64(index + 1) | mask)
                }
            }
            values.append(value)
            return Double(bitPattern: UInt64(values.count) | mask)
        }
        func load(_ arg: Double) -> Any {
            let bits = arg.bitPattern
            if bits & mask == mask {
                let index = Int(bits ^ mask) - 1
                if index >= 0, index < values.count {
                    return values[index]
                }
            }
            return arg
        }

        // Handle string literals and constants
        var numericConstants = [String: Double]()
        for symbol in expression.symbols {
            if case let .variable(name) = symbol {
                if let value = constants[name] {
                    numericConstants[name] = store(value)
                    continue
                }
                if name == "nil" {
                    let null: Any? = nil
                    numericConstants["nil"] = store(null as Any)
                    continue
                }
                if name.count >= 2, let first = name.first, "'\"".contains(first), name.last == first {
                    numericConstants[name] = store(String(name.dropFirst().dropLast()))
                }
            }
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
                return store(value)
            }
        }

        let expression = Expression(expression,
                                    options: options,
                                    constants: numericConstants,
                                    symbols: numericSymbols) { symbol, args in
            let anyArgs = args.map(load)
            if let value = try evaluator?(symbol, anyArgs) {
                return store(value)
            }
            if case .infix("??") = symbol {
                guard isOptional(anyArgs[0]) else {
                    throw Error.message("left hand argument of ?? operator must be optional")
                }
                return isNil(anyArgs[0]) ? args[1] : args[0]
            }
            if let doubleArgs = anyArgs as? [Double], !zip(doubleArgs, args).contains(where: {
                $0.0.bitPattern != $0.1.bitPattern // NaN-safe equality check
            }) {
                return nil // Fall back to default implementation
            }
            switch symbol {
            case .infix("=="):
                return args[0].bitPattern == args[1].bitPattern ? 1 : 0
            case .infix("!="):
                return args[0].bitPattern != args[1].bitPattern ? 1 : 0
            case .infix("?:") where anyArgs[0] is Double:
                return nil // Fall back to default implementation
            case .infix("+"):
                switch try (unwrap(anyArgs[0]), unwrap(anyArgs[1])) {
                case let (lhs as String, rhs):
                    return try store("\(lhs)\(stringify(rhs))")
                case let (lhs, rhs as String):
                    return try store("\(stringify(lhs))\(rhs)")
                default:
                    break
                }
                fallthrough
            default:
                if let fn = Expression.mathSymbols[symbol] {
                    var doubleArgs = [Double]()
                    for arg in anyArgs {
                        guard let doubleValue = (arg as? NSNumber).map({ Double(truncating: $0) }) else {
                            break
                        }
                        doubleArgs.append(doubleValue)
                    }
                    if doubleArgs.count == anyArgs.count {
                        // If we got here, the arguments are all numbers, but we're going to
                        // lose precision by converting them to doubles
                        // TODO: find alternative approach that doesn't lose precision
                        return try fn(doubleArgs)
                    }
                } else if !options.contains(.boolSymbols) || Expression.boolSymbols[symbol] == nil {
                    return nil
                }
            }
            throw Error.message("\(symbol) cannot be used with arguments of type (\(anyArgs.map { "\(type(of: $0))" }.joined(separator: ", ")))")
        }
        evaluate = {
            defer { values = literals }
            return try load(expression.evaluate())
        }
        self.symbols = expression.symbols
        description = expression.description
    }
}
