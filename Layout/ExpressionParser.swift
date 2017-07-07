//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

enum ParsedExpressionPart {
    case string(String)
    case expression(ParsedExpression)
}

// Preprocess the expression to find brace-delimited sub-expressions
// TODO: handle closing brace inside quotes within an expression
private func _parseExpression(_ expression: String) -> [ParsedExpressionPart] {
    var parts = [ParsedExpressionPart]()
    var range = expression.startIndex ..< expression.endIndex
    while let subrange = expression.range(of: "\\{[^}]*\\}", options: .regularExpression, range: range) {
        let string = expression.substring(with: range.lowerBound ..< subrange.lowerBound)
        if !string.isEmpty {
            parts.append(.string(string))
        }
        let expressionString = String(expression.characters[subrange].dropFirst().dropLast())
        let parsedExpression = Expression.parse(expressionString, usingCache: false)
        parts.append(.expression(parsedExpression))
        range = subrange.upperBound ..< range.upperBound
    }
    if !range.isEmpty {
        parts.append(.string(expression.substring(with: range)))
    }
    return parts
}

// NOTE: it is not safe to access this concurrently from multiple threads due to cache
private var _expressionCache = [String: ParsedExpression]()
func parseExpression(_ expression: String) -> ParsedExpression? {
    if let parsedExpression = _expressionCache[expression] {
        return parsedExpression
    }
    let parts = _parseExpression(expression.trimmingCharacters(in: .whitespacesAndNewlines))
    guard parts.count == 1 else {
        return nil // Malformed expression
    }
    let parsedExpression: ParsedExpression
    switch parts[0] {
    case let .string(string):
        parsedExpression = Expression.parse(string, usingCache: false)
    case let .expression(expression):
        parsedExpression = expression
    }
    _expressionCache[expression] = parsedExpression
    return parsedExpression
}

// NOTE: it is not safe to access this concurrently from multiple threads due to cache
private var _stringExpressionCache = [String: [ParsedExpressionPart]]()
func parseStringExpression(_ expression: String) -> [ParsedExpressionPart] {
    if let parts = _stringExpressionCache[expression] {
        return parts
    }
    let parts = _parseExpression(expression)
    _stringExpressionCache[expression] = parts
    return parts
}
