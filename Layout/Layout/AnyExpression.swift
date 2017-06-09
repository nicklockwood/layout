//
//  AnyExpression.swift
//  Expression
//
//  Created by Nick Lockwood on 18/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
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
import Expression

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

    static let maxValues = 256
    static let indexOffset = (Int64(2) << 52) - Int64(maxValues)

    init(_ expression: String,
         options: Options = .boolSymbols,
         constants: [String: Any] = [:],
         symbols: [Symbol: SymbolEvaluator] = [:],
         evaluator: Evaluator? = nil)
    {
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
         evaluator: Evaluator? = nil)
    {
        var values = [Any]()
        func store(_ value: Any) throws -> Double {
            if let value = (value as? NSNumber).map({ Double($0) }) {
                guard value <= Double(AnyExpression.indexOffset) else {
                    throw Error.message("Value \(value) is outside of the supported numeric range")
                }
                return value
            }
            if values.count == AnyExpression.maxValues {
                throw Error.message("Maximum number of stored values in an expression exceeded")
            }
            if let lhs = value as? AnyHashable {
                if let index = values.index(where: {
                    if let rhs = $0 as? AnyHashable {
                        return lhs == rhs
                    }
                    return false
                }) {
                    return Double(Int64(index) + AnyExpression.indexOffset)
                }
            } else if isNil(value), let index = values.index(where: { isNil($0) }) {
                return Double(Int64(index) + AnyExpression.indexOffset)
            }
            values.append(value)
            return Double(Int64(values.count - 1) + AnyExpression.indexOffset)
        }
        func load(_ arg: Double) -> Any {
            if let offsetIndex = Int64(exactly: arg),
                let index = Int(exactly: offsetIndex - AnyExpression.indexOffset),
                index >= 0, index < values.count {
                return values[index]
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
                                    symbols: numericSymbols)
        { symbol, args in
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
            case .infix("?:") where anyArgs[0] is Double,
                 .infix("=="),
                 .infix("!="):
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
