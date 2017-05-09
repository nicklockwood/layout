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
    let symbols: Set<Expression.Symbol>
    let description: String

    typealias Evaluator = (_ symbol: Expression.Symbol, _ args: [Any]) throws -> Any?

    init(_ expression: String,
         symbols: [Expression.Symbol: Expression.Symbol.Evaluator],
         evaluator: @escaping Evaluator)
    {
        var values = [Any]()
        let offset: Int64 = 5_000_000_000 // Reduce false-positive matches using values outside normal Int range
        func store(_ value: Any) -> Double {
            if let value = (value as? NSNumber).map({ Double($0) }) {
                return value
            }
            values.append(value)
            return Double(Int64(values.count) + offset - 1)
        }
        func load(_ arg: Double) -> Any {
            if let offsetIndex = Int64(exactly: arg) {
                if let index = Int(exactly: offsetIndex - offset), index >= 0, index < values.count {
                    return values[index]
                }
                return offsetIndex
            }
            return arg
        }
        let expression = Expression(
            expression,
            symbols: symbols
        ) { symbol, args in
            let anyArgs = args.map(load)
            if let value = try evaluator(symbol, args) {
                return store(value)
            }
            switch symbol {
            case .infix("+") where !values.isEmpty:
                return store("\(anyArgs[0])\(anyArgs[1])")
            case .infix("=="):
                guard let hashableArgs = anyArgs as? [AnyHashable] else {
                    return nil
                }
                return hashableArgs[0] == hashableArgs[1] ? 1 : 0
            case .infix("!="):
                guard let hashableArgs = anyArgs as? [AnyHashable] else {
                    return nil
                }
                return hashableArgs[0] != hashableArgs[1] ? 1 : 0
            case .infix("?:"):
                return nil // Use default implementation
            default:
                return nil // Fall back to default implementation
            }
        }
        evaluate = {
            let value = try load(expression.evaluate())
            values.removeAll()
            return value
        }
        self.symbols = expression.symbols
        description = expression.description
    }
}
