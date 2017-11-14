//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

// Prevent cache from distorting performance test results
let runningInUnitTest = (NSClassFromString("XCTestCase") != nil)

struct ParsedLayoutExpression: CustomStringConvertible {
    var expression: ParsedExpression
    var comment: String?

    init(_ expression: ParsedExpression, comment: String?) {
        self.expression = expression
        self.comment = comment
    }

    var description: String {
        let description = expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comment = comment else {
            return description
        }
        if description.isEmpty {
            return "// \(comment)"
        }
        return "\(expression) // \(comment)"
    }

    var isEmpty: Bool { return error == .unexpectedToken("") }
    var symbols: Set<Expression.Symbol> { return expression.symbols }
    var error: Expression.Error? { return expression.error }
}

enum ParsedExpressionPart {
    case string(String)
    case comment(String)
    case expression(ParsedLayoutExpression)
}

// NOTE: it is not safe to access this concurrently from multiple threads due to cache
private var _expressionCache = [String: ParsedLayoutExpression]()
func parseExpression(_ expression: String) throws -> ParsedLayoutExpression {
    if let parsedExpression = _expressionCache[expression] {
        return parsedExpression
    }
    let parsedExpression: ParsedExpression
    var comment: String?
    var characters = String.UnicodeScalarView.SubSequence(expression.unicodeScalars)
    characters.skipWhitespace()
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
    if let error = parsedExpression.error, error != .unexpectedToken("") {
        throw error
    }
    characters.skipWhitespace()
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
    if let comment = characters.readComment(upTo: nil) {
        return [.comment(comment)]
    } else {
        while let char = characters.first {
            switch char {
            case "{":
                characters.removeFirst()
                if !string.isEmpty {
                    parts.append(.string(string))
                    string = ""
                }
                let parsedExpression = Expression.parse(&characters, upTo: "}", "//")
                if let error = parsedExpression.error, error != .unexpectedToken("") {
                    throw error
                }
                let comment = characters.readComment(upTo: "}")
                parts.append(.expression(ParsedLayoutExpression(parsedExpression, comment: comment)))
                if characters.first != "}" {
                    throw Expression.Error.message("Missing `}`")
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
    }
    if !runningInUnitTest {
        _stringExpressionCache[expression] = parts
    }
    return parts
}

private let whitespaceChars = CharacterSet.whitespacesAndNewlines

private extension String.UnicodeScalarView.SubSequence {
    mutating func skipWhitespace() {
        while let char = first, whitespaceChars.contains(char) {
            removeFirst()
        }
    }

    mutating func readComment(upTo delimiter: UnicodeScalar?) -> String? {
        let start = self
        skipWhitespace()
        guard popFirst() == "/", popFirst() == "/" else {
            self = start
            return nil
        }
        guard let delimiter = delimiter else {
            let comment = String(self).trimmingCharacters(in: .whitespacesAndNewlines)
            removeAll()
            return comment
        }
        var output = String.UnicodeScalarView.SubSequence()
        while first != delimiter {
            output.append(removeFirst())
        }
        return String(output).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
