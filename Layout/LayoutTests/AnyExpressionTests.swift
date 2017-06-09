//
//  AnyExpressionTests.swift
//  Layout
//
//  Created by Nick Lockwood on 13/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import XCTest
import Expression
@testable import Layout

class AnyExpressionTests: XCTestCase {

    func testAddNumbers() {
        let expression = AnyExpression("4 + 5")
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? Double, 9)
    }

    func testAddNumericConstants() {
        let expression = AnyExpression("a + b", constants: [
            "a": 4,
            "b": 5,
        ])
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(try expression.evaluate() as? Double, 9)
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

    func testAddStringVariables() {
        let expression = AnyExpression("a + b", symbols: [
            .variable("a"): { _ in "foo" },
            .variable("b"): { _ in "bar" },
        ])
        XCTAssertEqual(expression.symbols, [.variable("a"), .variable("b"), .infix("+")])
        XCTAssertEqual(try expression.evaluate() as? String, "foobar")
    }

    func testAddStringVariables2() {
        let expression = AnyExpression("a + b") { symbol, args in
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

    func testAddNumbersJustInsideIndexRange() {
        let expression = AnyExpression("a + b", constants: [
            "a": Double(AnyExpression.indexOffset) - 17,
            "b": 5,
        ])
        XCTAssertEqual(try expression.evaluate() as? Double, Double(AnyExpression.indexOffset) - 12)
    }

    func testAddNumbersOutsideIndexRange() {
        let expression = AnyExpression("a + b", constants: [
            "a": Double(AnyExpression.indexOffset) + 4,
            "b": 5,
        ])
        XCTAssertThrowsError(try expression.evaluate()) { error in
            guard case let Expression.Error.message(message) = error,
                message.contains("numeric range") else {
                XCTFail()
                return
            }
        }
    }

    func testMaxConstantCountExceeded() {
        var constants = [String: String]()
        for i in 0 ..< AnyExpression.maxValues {
            constants["v\(i)"] = "\(i)"
        }
        let expression = AnyExpression(constants.keys.joined(separator: "+"), constants: constants)
        XCTAssertThrowsError(try expression.evaluate()) { error in
            guard case let Expression.Error.message(message) = error,
                message.contains("number of stored values") else {
                XCTFail()
                return
            }
        }
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
}
