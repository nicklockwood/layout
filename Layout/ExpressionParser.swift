//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

enum ParsedExpressionPart {
    case string(String)
    case expression(ParsedExpression)
}

// NOTE: it is not safe to access this concurrently from multiple threads due to cache
private var _expressionCache = [String: ParsedExpression]()
func parseExpression(_ expression: String) throws -> ParsedExpression {
    if let parsedExpression = _expressionCache[expression] {
        return parsedExpression
    }
    let parsedExpression: ParsedExpression
    var characters = expression.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars
    switch characters.first ?? " " {
    case "{":
        characters.removeFirst()
        parsedExpression = try Expression.parse(&characters)
        if characters.first != "}" {
            throw Expression.Error.message("Missing `}`")
        }
        characters.removeFirst()
    case "}":
        throw Expression.Error.message("Unexpected `}`")
    default:
        parsedExpression = try Expression.parse(&characters)
    }
    if !characters.isEmpty {
        throw Expression.Error.message("Unexpected token `\(String(characters))`")
    }
    _expressionCache[expression] = parsedExpression
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
    var characters = expression.unicodeScalars
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
    _stringExpressionCache[expression] = parts
    return parts
}
