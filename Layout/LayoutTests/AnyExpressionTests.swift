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
        XCTAssertEqual(try expression.evaluate() as? Double, 9)
    }

    func testAddNumericConstants() {
        let expression = AnyExpression("a + b", symbols: [
            .constant("a"): { _ in 4 },
            .constant("b"): { _ in 5 },
        ])
        XCTAssertEqual(try expression.evaluate() as? Double, 9)
    }

    func testAddStringConstants() {
        let expression = AnyExpression("a + b") { symbol, args in
            switch symbol {
            case .constant("a"):
                return "foo"
            case .constant("b"):
                return "bar"
            default:
                return nil
            }
        }
        XCTAssertEqual(try expression.evaluate() as? String, "foobar")
    }

    func testEquateStrings() {
        let evaluator: AnyExpression.Evaluator = { symbol, args in
            switch symbol {
            case .constant("a"):
                return "foo"
            case .constant("b"):
                return "bar"
            case .constant("c"):
                return "bar"
            default:
                return nil
            }
        }
        let expression1 = AnyExpression("a == b", evaluator: evaluator)
        XCTAssertEqual(try expression1.evaluate() as? Double, 0)
        let expression2 = AnyExpression("a != b", evaluator: evaluator)
        XCTAssertEqual(try expression2.evaluate() as? Double, 1)
        let expression3 = AnyExpression("b == c", evaluator: evaluator)
        XCTAssertEqual(try expression3.evaluate() as? Double, 1)
    }

    func testEquateObjects() {
        let object1 = NSObject()
        let object2 = NSObject()
        let evaluator: AnyExpression.Evaluator = { symbol, args in
            switch symbol {
            case .constant("a"):
                return object1
            case .constant("b"):
                return object2
            case .constant("c"):
                return object2
            default:
                return nil
            }
        }
        let expression1 = AnyExpression("a == b", evaluator: evaluator)
        XCTAssertEqual(try expression1.evaluate() as? Double, 0)
        let expression2 = AnyExpression("a != b", evaluator: evaluator)
        XCTAssertEqual(try expression2.evaluate() as? Double, 1)
        let expression3 = AnyExpression("b == c", evaluator: evaluator)
        XCTAssertEqual(try expression3.evaluate() as? Double, 1)
    }

    func testAddNumbersJustInsideIndexRange() {
        let expression = AnyExpression("a + b") { symbol, args in
            switch symbol {
            case .constant("a"):
                return Double(AnyExpression.indexOffset) - 17
            case .constant("b"):
                return 5
            default:
                return nil
            }
        }
        XCTAssertEqual(try expression.evaluate() as? Double, Double(AnyExpression.indexOffset) - 12)
    }

    func testAddNumbersOutsideIndexRange() {
        let expression = AnyExpression("a + b") { symbol, args in
            switch symbol {
            case .constant("a"):
                return Double(AnyExpression.indexOffset) + 4
            case .constant("b"):
                return 5
            default:
                return nil
            }
        }
        XCTAssertThrowsError(try expression.evaluate()) { error in
            guard case let Expression.Error.message(message) = error,
                message.contains("numeric range") else {
                XCTFail()
                return
            }
        }
    }

    func testMaxConstantCountExceeded() {
        var contants = [String: String]()
        for i in 0 ..< AnyExpression.maxValues {
            contants["v\(i)"] = "\(i)"
        }
        let expression = AnyExpression(contants.keys.joined(separator: "+")) { symbol, args in
            switch symbol {
            case let .constant(name):
                return contants[name]
            default:
                return nil
            }
        }
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
        XCTAssertEqual(try expression.evaluate() as? String, "foobar")
    }
}
