//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

enum ParsedExpressionPart {
    case string(String)
    case expression(ParsedExpression)
}

// Prevent cache from distorting performance test results
private let runningInUnitTest = (NSClassFromString("XCTestCase") != nil)

// NOTE: it is not safe to access this concurrently from multiple threads due to cache
private var _expressionCache = [String: ParsedExpression]()
func parseExpression(_ expression: String) throws -> ParsedExpression {
    if let parsedExpression = _expressionCache[expression] {
        return parsedExpression
    }
    let parsedExpression: ParsedExpression
    var characters = String.UnicodeScalarView.SubSequence(
        expression.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
    switch characters.first ?? " " {
    case "{":
        characters.removeFirst()
        parsedExpression = try Expression.parse(&characters)
        if characters.first != "}" {
            throw Expression.Error.message("Missing `}`")
        }
        characters.removeFirst()
    default:
        parsedExpression = try Expression.parse(&characters)
    }
    if !characters.isEmpty {
        throw Expression.Error.message("Unexpected token `\(String(characters))`")
    }
    if !runningInUnitTest {
        _expressionCache[expression] = parsedExpression
    }
    return parsedExpression
}

// NOTE: it is not safe to access this concurrently from multiple threads due to cache
private var _stringExpressionCache = [String: [ParsedExpressionPart]]()
func parseStringExpression(_ expression: String) throws -> [ParsedExpressionPart] {
    if let parts = _stringExpressionCache[expression] {
        return parts
    }
    var parts = [ParsedExpressionPart]()
    var string = ""
    var characters = String.UnicodeScalarView.SubSequence(expression.unicodeScalars)
    while let char = characters.first {
        switch char {
        case "{":
            characters.removeFirst()
            if !string.isEmpty {
                parts.append(.string(string))
                string = ""
            }
            parts.append(.expression(try Expression.parse(&characters)))
            if characters.first != "}" {
                fallthrough
            }
            characters.removeFirst()
        case "}":
            throw Expression.Error.message("Unexpected `}`")
        default:
            characters.removeFirst()
            string.append(Character(char))
        }
    }
    if !string.isEmpty {
        parts.append(.string(string))
    }
    if !runningInUnitTest {
        _stringExpressionCache[expression] = parts
    }
    return parts
}

// Check that the expression symbols are valid (or at least plausible)
func validateLayoutExpression(_ parsedExpression: ParsedExpression) throws {
    let keys = Set(Expression.mathSymbols.keys).union(Expression.boolSymbols.keys).union([
        .postfix("%"),
        .function("rgb", arity: 3),
        .function("rgba", arity: 4),
    ])
    for symbol in parsedExpression.symbols {
        switch symbol {
        case .variable:
            break
        case .prefix, .infix, .postfix:
            guard keys.contains(symbol) else {
                throw Expression.Error.undefinedSymbol(symbol)
            }
        case let .function(called, arity):
            guard keys.contains(symbol) else {
                for case let .function(name, requiredArity) in keys
                    where name == called && arity != requiredArity {
                    throw Expression.Error.arityMismatch(.function(called, arity: requiredArity))
                }
                throw Expression.Error.undefinedSymbol(symbol)
            }
        }
    }
}
