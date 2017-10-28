//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class AnyExpressionTests: XCTestCase {

    func testAddNumbers() {
        let expression = AnyExpression("4 + 5")
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? Double, 9)
    }

    func testAddNumericConstants() {
        let expression = AnyExpression("a + b", constants: [
            "a": UInt64(4),
            "b": 5,
        ])
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? Double, 9)
    }

    func testPreserveNumericPrecision() {
        let expression = AnyExpression("true ? a : b", constants: [
            "a": UInt64.max,
            "b": Int64.min,
        ])
        XCTAssertEqual(try expression.evaluate() as? UInt64, .max)
    }

    func testAddVeryLargeNumericConstants() {
        let expression = AnyExpression("a + b", constants: [
            "a": Int64.max,
            "b": Int64.max,
        ])
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? Double, Double(Int64.max) + Double(Int64.max))
    }

    func testNaN() {
        let expression = AnyExpression("NaN + 5", constants: ["NaN": Double.nan])
        XCTAssertEqual((try expression.evaluate() as? Double)?.isNaN, true)
    }

    func testEvilEdgeCase() {
        let evilValue = (-Double.nan) // exactly matches mask
        let expression = AnyExpression("evil + 5", constants: ["evil": evilValue])
        XCTAssertEqual((try expression.evaluate() as? Double)?.bitPattern, evilValue.bitPattern)
    }

    func testEvilEdgeCase2() {
        let evilValue = Double(bitPattern: (-Double.nan).bitPattern + 2) // outside range of stored variables
        let expression = AnyExpression("evil + 5", constants: ["evil": evilValue])
        XCTAssertEqual((try expression.evaluate() as? Double)?.bitPattern, evilValue.bitPattern)
    }

    func testFloatNaN() {
        let expression = AnyExpression("NaN + 5", constants: ["NaN": Float.nan])
        XCTAssertEqual((try expression.evaluate() as? Double)?.isNaN, true)
    }

    func testInfinity() {
        let expression = AnyExpression("1/0")
        XCTAssertEqual((try expression.evaluate() as? Double)?.isInfinite, true)
    }

    func testAddStringConstants() {
        let expression = AnyExpression("a + b", constants: [
            "a": "foo",
            "b": "bar",
        ])
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "foobar")
    }

    func testAddNumericConstantsWithString() {
        let expression = AnyExpression("a + b == 9 ? c : ''", constants: [
            "a": 4,
            "b": 5,
            "c": "foo",
        ])
        XCTAssertEqual(expression.symbols, [.infix("+"), .infix("=="), .infix("?:")])
        XCTAssertEqual(try expression.evaluate() as? String, "foo")
    }

    func testAddNumberToString() {
        let expression = AnyExpression("5 + 'foo'")
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "5foo")
    }

    func testAddStringToNumber() {
        let expression = AnyExpression("'foo' + 5")
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "foo5")
    }

    func testAddStringVariables() {
        let expression = AnyExpression("a + b", symbols: [
            .variable("a"): { _ in "foo" },
            .variable("b"): { _ in "bar" },
        ])
        XCTAssertEqual(expression.symbols, [.variable("a"), .variable("b"), .infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "foobar")
    }

    func testAddStringVariables2() {
        let expression = AnyExpression("a + b") { symbol, _ in
            switch symbol {
            case .variable("a"):
                return "foo"
            case .variable("b"):
                return "bar"
            default:
                return nil
            }
        }
        XCTAssertEqual(expression.symbols, [.variable("a"), .variable("b"), .infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "foobar")
    }

    func testMixedConstantsAndVariables() {
        let expression = AnyExpression(
            "a + b + c",
            constants: [
                "a": "foo",
                "b": "bar",
            ],
            symbols: [
                .variable("c"): { _ in "baz" },
            ]
        )
        XCTAssertEqual(expression.symbols, [.variable("c"), .infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "foobarbaz")
    }

    func testMixedConstantsAndVariables2() {
        let expression = AnyExpression(
            "foo ? #F00 : #00F",
            constants: [
                "#F00": UIColor(red: 1, green: 0, blue: 0, alpha: 1),
                "#00F": UIColor(red: 0, green: 0, blue: 1, alpha: 1),
            ],
            symbols: [
                .variable("foo"): { _ in true },
            ]
        )
        XCTAssertEqual(expression.symbols, [.variable("foo"), .infix("?:")])
        XCTAssertEqual(try expression.evaluate() as? UIColor, UIColor(red: 1, green: 0, blue: 0, alpha: 1))
    }

    func testEquateStrings() {
        let constants: [String: Any] = [
            "a": "foo",
            "b": "bar",
            "c": "bar",
        ]
        let expression1 = AnyExpression("a == b", constants: constants)
        XCTAssertEqual(try expression1.evaluate() as? Double, 0)
        let expression2 = AnyExpression("a != b", constants: constants)
        XCTAssertEqual(try expression2.evaluate() as? Double, 1)
        let expression3 = AnyExpression("b == c", constants: constants)
        XCTAssertEqual(try expression3.evaluate() as? Double, 1)
        let expression4 = AnyExpression("b != c", constants: constants)
        XCTAssertEqual(try expression4.evaluate() as? Double, 0)
    }

    func testEquateObjects() {
        let object1 = NSObject()
        let object2 = NSObject()
        let constants: [String: Any] = [
            "a": object1,
            "b": object2,
            "c": object2,
        ]
        let expression1 = AnyExpression("a == b", constants: constants)
        XCTAssertEqual(try expression1.evaluate() as? Double, 0)
        let expression2 = AnyExpression("a != b", constants: constants)
        XCTAssertEqual(try expression2.evaluate() as? Double, 1)
        let expression3 = AnyExpression("b == c", constants: constants)
        XCTAssertEqual(try expression3.evaluate() as? Double, 1)
    }

    func testStringLiterals() {
        let expression = AnyExpression("'foo' + 'bar'")
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "foobar")
    }

    func testNilString() {
        let null: String? = nil
        let expression = AnyExpression("foo + 'bar'", constants: ["foo": null as Any])
        XCTAssertThrowsError(try expression.evaluate()) { error in
            XCTAssert("\(error)".contains("nil"))
        }
    }

    func testNilString2() {
        let null: String? = nil
        let expression1 = AnyExpression("foo == nil ? 'bar' : foo", constants: ["foo": null as Any])
        XCTAssertEqual(try expression1.evaluate() as? String, "bar")
        let expression2 = AnyExpression("foo == nil ? 'bar' : foo", constants: ["foo": "foo"])
        XCTAssertEqual(try expression2.evaluate() as? String, "foo")
    }

    func testNilColor() {
        let null: UIColor? = nil
        let expression1 = AnyExpression("foo == nil ? bar : foo", constants: ["foo": null as Any, "bar": UIColor.red])
        XCTAssertEqual(try expression1.evaluate() as? UIColor, .red)
        let expression2 = AnyExpression("foo == nil ? bar : foo", constants: ["foo": UIColor.green, "bar": UIColor.red])
        XCTAssertEqual(try expression2.evaluate() as? UIColor, .green)
    }

    func testNullCoalescing() {
        let null: String? = nil
        let expression = AnyExpression("foo ?? 'bar'", constants: ["foo": null as Any])
        XCTAssertEqual(try expression.evaluate() as? String, "bar")
    }

    func testUnknownOperator() {
        let expression = AnyExpression("'foo' %% 'bar'")
        XCTAssertThrowsError(try expression.evaluate()) { error in
            XCTAssert("\(error)".contains("Undefined infix operator %%"))
        }
    }

    func testTypeMismatch() {
        let expression = AnyExpression("5 / 'foo'")
        XCTAssertThrowsError(try expression.evaluate()) { error in
            XCTAssert("\(error)".contains("cannot be used with arguments of type (Double, String)"))
        }
    }
}
