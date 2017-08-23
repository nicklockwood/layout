//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

struct ParsedLayoutExpression: CustomStringConvertible {
    var expression: ParsedExpression
    var comment: String?

    init(_ expression: ParsedExpression, comment: String?) {
        self.expression = expression
        self.comment = comment
    }

    var description: String {
        guard let comment = comment else {
            return expression.description
        }
        return "\(expression) // \(comment)"
    }

    var symbols: Set<Expression.Symbol> { return expression.symbols }
    var error: Expression.Error? { return expression.error }
}

enum ParsedExpressionPart {
    case string(String)
    case expression(ParsedLayoutExpression)
}

// Prevent cache from distorting performance test results
private let runningInUnitTest = (NSClassFromString("XCTestCase") != nil)

// NOTE: it is not safe to access this concurrently from multiple threads due to cache
private var _expressionCache = [String: ParsedLayoutExpression]()
func parseExpression(_ expression: String) throws -> ParsedLayoutExpression {
    if let parsedExpression = _expressionCache[expression] {
        return parsedExpression
    }
    let parsedExpression: ParsedExpression
    var comment: String?
    var characters = String.UnicodeScalarView.SubSequence(
        expression.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
    switch characters.first ?? " " {
    case "{":
        characters.removeFirst()
        parsedExpression = Expression.parse(&characters, upTo: "}", "//")
        comment = characters.readComment(upTo: "}")
        if characters.first != "}" {
            throw Expression.Error.message("Missing `}`")
        }
        characters.removeFirst()
    default:
        parsedExpression = Expression.parse(&characters, upTo: "//")
        comment = characters.readComment(upTo: nil)
    }
    if let error = parsedExpression.error {
        throw error
    }
    if !characters.isEmpty {
        throw Expression.Error.message("Unexpected token `\(String(characters))`")
    }
    let parsedLayoutExpression = ParsedLayoutExpression(parsedExpression, comment: comment)
    if !runningInUnitTest {
        _expressionCache[expression] = parsedLayoutExpression
    }
    return parsedLayoutExpression
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
            let parsedExpression = Expression.parse(&characters, upTo: "}", "//")
            if let error = parsedExpression.error {
                throw error
            }
            let comment = characters.readComment(upTo: "}")
            parts.append(.expression(ParsedLayoutExpression(parsedExpression, comment: comment)))
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
func validateLayoutExpression(_ parsedExpression: ParsedLayoutExpression) throws {
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

private extension String.UnicodeScalarView.SubSequence {
    mutating func readComment(upTo delimiter: UnicodeScalar?) -> String? {
        var comment: String?
        if count >= 2, first == "/", self[index(after: startIndex)] == "/" {
            removeFirst(2)
            guard let delimiter = delimiter else {
                comment = String(self).trimmingCharacters(in: .whitespacesAndNewlines)
                removeAll()
                return comment
            }
            var output = String.UnicodeScalarView()
            while let char = first, char != delimiter {
                removeFirst()
                output.append(char)
            }
            comment = String(output).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return comment
    }
}
