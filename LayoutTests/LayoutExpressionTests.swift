//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class LayoutExpressionTests: XCTestCase {

    // MARK: Expression parsing

    func testParseExpressionWithoutBraces() {
        let expression = parseExpression("4 + 5")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithBraces() {
        let expression = parseExpression("{4 + 5}")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithBracesAndWhitespace() {
        let expression = parseExpression(" {4 + 5} ")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithLeadingGarbage() {
        let expression = parseExpression("foo {4 + 5}")
        XCTAssertNil(expression)
    }

    func testParseExpressionWithTrailingGarbage() {
        let expression = parseExpression("{4 + 5} foo")
        XCTAssertNil(expression)
    }

    func testParseEmptyExpression() {
        let expression = parseExpression("")
        XCTAssertNil(expression)
    }

    func testParseExpressionWithEmptyBraces() {
        let expression = parseExpression("{}")
        XCTAssertNotNil(expression)
        XCTAssertNotNil(expression?.error)
    }

    func testParseExpressionOpeningBrace() {
        let expression = parseExpression("{")
        XCTAssertNotNil(expression)
        XCTAssertNotNil(expression?.error)
    }

    func testParseExpressionWithClosingBrace() {
        let expression = parseExpression("}")
        XCTAssertNotNil(expression)
        XCTAssertNotNil(expression?.error)
    }

    func testParseExpressionWithMissingClosingBrace() {
        let expression = parseExpression("{4 + 5")
        XCTAssertNotNil(expression)
        XCTAssertNotNil(expression?.error)
    }

    func testParseExpressionWithMissingOpeningBrace() {
        let expression = parseExpression("4 + 5}")
        XCTAssertNotNil(expression)
        XCTAssertNotNil(expression?.error)
    }

    func testParseExpressionWithExtraOpeningBrace() {
        let expression = parseExpression("{{4 + 5}")
        XCTAssertNotNil(expression)
        XCTAssertNotNil(expression?.error)
    }

    func testParseExpressionWithExtraClosingBrace() {
        let expression = parseExpression("{4 + 5}}")
        XCTAssertNil(expression)
    }

    // MARK: String expression parsing

    func testParseStringExpressionWithoutBraces() {
        let parts = parseStringExpression("4 + 5")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .string(string) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(string, "4 + 5")
    }

    func testParseStringExpressionWithBraces() {
        let parts = parseStringExpression("{4 + 5}")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(expression.symbols, [.infix("+")])
    }

    func testParseStringExpressionWithBracesAndWhitespace() {
        let parts = parseStringExpression(" {4 + 5} ")
        guard parts.count == 3 else {
            XCTFail()
            return
        }
        guard case let .string(a) = parts[0], a == " " else {
            XCTFail()
            return
        }
        guard case let .expression(b) = parts[1], b.symbols == [.infix("+")] else {
            XCTFail()
            return
        }
        guard case let .string(c) = parts[2], c == " " else {
            XCTFail()
            return
        }
    }

    func testParseStringExpressionWithMultipleBraces() {
        let parts = parseStringExpression("{4} + {5}")
        guard parts.count == 3 else {
            XCTFail()
            return
        }
        guard case let .expression(a) = parts[0], a.symbols == [] else {
            XCTFail()
            return
        }
        guard case let .string(b) = parts[1], b == " + " else {
            XCTFail()
            return
        }
        guard case let .expression(c) = parts[2], c.symbols == [] else {
            XCTFail()
            return
        }
    }

    func testParseEmptyStringExpression() {
        let parts = parseStringExpression("")
        XCTAssertTrue(parts.isEmpty)
    }

    func testParseStringExpressionWithEmptyBraces() {
        let parts = parseStringExpression("{}")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNotNil(expression.error)
    }

    func testParseStringExpressionOpeningBrace() {
        let parts = parseStringExpression("{")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .string(string) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(string, "{")
    }

    func testParseStringExpressionClosingBrace() {
        let parts = parseStringExpression("}")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .string(string) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(string, "}")
    }

    func testParseStringExpressionWithMissingClosingBrace() {
        let parts = parseStringExpression("{4 + 5")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .string(string) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(string, "{4 + 5")
    }

    func testParseStringExpressionWithMissingOpeningBrace() {
        let parts = parseStringExpression("4 + 5}")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .string(string) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(string, "4 + 5}")
    }

    func testParseStringExpressionWithExtraOpeningBrace() {
        let parts = parseStringExpression("{{4 + 5}")
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNotNil(expression.error)
    }

    func testParseStringExpressionWithExtraClosingBrace() {
        let parts = parseStringExpression("{4 + 5}}")
        guard parts.count == 2 else {
            XCTFail()
            return
        }
        guard case let .expression(a) = parts[0], a.symbols == [.infix("+")] else {
            XCTFail()
            return
        }
        guard case let .string(b) = parts[1], b == "}" else {
            XCTFail()
            return
        }
    }

    // MARK: Integration tests

    func testOptionalBracesInNumberExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(numberExpression: "{4 + 5}", for: node)
        XCTAssertEqual(try expression.evaluate() as? Double, 9)
    }

    func testOptionalBracesInColorExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(colorExpression: "{#fff}", for: node)
        XCTAssertEqual(try expression.evaluate() as? UIColor, UIColor(red: 1, green: 1, blue: 1, alpha: 1))
    }

    func testOptionalMultipleExpressionBodiesDisallowedInNumberExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(numberExpression: "{5}{6}", for: node)
        XCTAssertThrowsError(try expression.evaluate())
    }
}
