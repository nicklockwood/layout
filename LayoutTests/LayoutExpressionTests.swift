//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class LayoutExpressionTests: XCTestCase {

    // MARK: Expression parsing

    func testParseExpressionWithoutBraces() {
        let expression = try? parseExpression("4 + 5")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithBraces() {
        let expression = try? parseExpression("{4 + 5}")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithBracesAndWhitespace() {
        let expression = try? parseExpression(" {4 + 5} ")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithLeadingGarbage() {
        XCTAssertThrowsError(try parseExpression("foo {4 + 5}"))
    }

    func testParseExpressionWithTrailingGarbage() {
        XCTAssertThrowsError(try parseExpression("{4 + 5} foo"))
    }

    func testParseEmptyExpression() {
        XCTAssertThrowsError(try parseExpression(""))
    }

    func testParseExpressionWithEmptyBraces() {
        XCTAssertThrowsError(try parseExpression("{}"))
    }

    func testParseExpressionOpeningBrace() {
        XCTAssertThrowsError(try parseExpression("{"))
    }

    func testParseExpressionWithClosingBrace() {
        XCTAssertThrowsError(try parseExpression("}"))
    }

    func testParseExpressionWithMissingClosingBrace() {
        XCTAssertThrowsError(try parseExpression("{4 + 5"))
    }

    func testParseExpressionWithMissingOpeningBrace() {
        XCTAssertThrowsError(try parseExpression("4 + 5}"))
    }

    func testParseExpressionWithExtraOpeningBrace() {
        XCTAssertThrowsError(try parseExpression("{{4 + 5}"))
    }

    func testParseExpressionWithExtraClosingBrace() {
        XCTAssertThrowsError(try parseExpression("{4 + 5}}"))
    }

    func testParseExpressionWithClosingBraceInQuotes() {
        let expression = try? parseExpression("{'}'}")
        XCTAssertNotNil(expression)
        XCTAssertNil(expression?.error)
    }

    func testParseExpressionWithOpeningBraceInQuotes() {
        let expression = try? parseExpression("{'{'}")
        XCTAssertNotNil(expression)
        XCTAssertNil(expression?.error)
    }

    func testParseExpressionWithBracesInQuotes() {
        let expression = try? parseExpression("{'{foo}'}")
        XCTAssertNotNil(expression)
        XCTAssertNil(expression?.error)
    }

    // MARK: String expression parsing

    func testParseStringExpressionWithoutBraces() {
        let parts = (try? parseStringExpression("4 + 5")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .string(string) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(string, "4 + 5")
    }

    func testParseStringExpressionWithBraces() {
        let parts = (try? parseStringExpression("{4 + 5}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(expression.symbols, [.infix("+")])
    }

    func testParseStringExpressionWithBracesAndWhitespace() {
        let parts = (try? parseStringExpression(" {4 + 5} ")) ?? []
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
        let parts = (try? parseStringExpression("{4} + {5}")) ?? []
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
        do {
            let parts = try parseStringExpression("")
            XCTAssertTrue(parts.isEmpty)
        } catch {
            XCTFail()
        }
    }

    func testParseStringExpressionWithEmptyBraces() {
        XCTAssertThrowsError(try parseStringExpression("{}"))
    }

    func testParseStringExpressionOpeningBrace() {
        XCTAssertThrowsError(try parseStringExpression("{"))
    }

    func testParseStringExpressionClosingBrace() {
        XCTAssertThrowsError(try parseStringExpression("}"))
    }

    func testParseStringExpressionWithMissingClosingBrace() {
        XCTAssertThrowsError(try parseStringExpression("{4 + 5"))
    }

    func testParseStringExpressionWithMissingOpeningBrace() {
        XCTAssertThrowsError(try parseStringExpression("4 + 5}"))
    }

    func testParseStringExpressionWithExtraOpeningBrace() {
        XCTAssertThrowsError(try parseStringExpression("{{4 + 5}"))
    }

    func testParseStringExpressionWithExtraClosingBrace() {
        XCTAssertThrowsError(try parseStringExpression("{4 + 5}}"))
    }

    func testParseStringExpressionWithClosingBraceInQuotes() {
        let parts = (try? parseStringExpression("{'}'}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNil(expression.error)
    }

    func testParseStringExpressionWithOpeningBraceInQuotes() {
        let parts = (try? parseStringExpression("{'{'}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNil(expression.error)
    }

    func testParseStringExpressionWithBracesInQuotes() {
        let parts = (try? parseStringExpression("{'{foo}'}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNil(expression.error)
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
