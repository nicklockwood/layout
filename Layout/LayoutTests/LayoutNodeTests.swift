//
//  LayoutNodeTests.swift
//  LayoutNodeTests
//
//  Created by Nick Lockwood on 22/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import XCTest
@testable import Layout

class LayoutNodeTests: XCTestCase {

    func testCircularReference1() {
        let node = LayoutNode(expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("Circular reference") == true)
        XCTAssertTrue(errors.first?.description.contains("top") == true)
    }

    func testCircularReference2() {
        let node = LayoutNode(expressions: ["top": "bottom", "bottom": "top"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 2)
        for error in errors {
            let description = error.description
            XCTAssertTrue(description.contains("Circular reference"))
            XCTAssertTrue(description.contains("top") || description.contains("bottom"))
        }
    }

    func testExpressionShadowsConstant() {
        let node = LayoutNode(constants: ["top": 10], expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertTrue(errors.isEmpty)
    }

    func testExpressionShadowsVariable() {
        let node = LayoutNode(state: ["top": 10], expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertTrue(errors.isEmpty)
    }
}
