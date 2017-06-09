//
//  LayoutExpressionTests.swift
//  Layout
//
//  Created by Nick Lockwood on 09/06/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import XCTest
@testable import Layout

class LayoutExpressionTests: XCTestCase {
    
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

    func testNullCoalescingInNumberExpression() {
        let null: Double? = nil
        let node = LayoutNode(constants: ["foo" : null as Any])
        let expression = LayoutExpression(numberExpression: "foo ?? 5", for: node)
        XCTAssertEqual(try expression.evaluate() as? Double, 5)
    }

    func testNullStringExpression() {
        let null: String? = nil
        let node = LayoutNode(constants: ["foo" : null as Any])
        let expression = LayoutExpression(stringExpression: "{foo}", for: node)
        XCTAssertEqual(try expression.evaluate() as? String, "")
    }

    func testNullImageExpression() {
        let null: UIImage? = nil
        let node = LayoutNode(constants: ["foo" : null as Any])
        let expression = LayoutExpression(imageExpression: "{foo}", for: node)
        XCTAssertEqual((try expression.evaluate() as? UIImage).map { $0.size }, .zero)
    }

    func testNullAnyExpression() {
        let null: Any? = nil
        let node = LayoutNode(constants: ["foo" : null as Any])
        let expression = LayoutExpression(expression: "foo", ofType: RuntimeType(Any.self), for: node)
        XCTAssertThrowsError(try expression.evaluate()) { error in
            XCTAssert("\(error)".contains("nil"))
        }
    }
}
