//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class ArrayExpressionTests: XCTestCase {

    func testSetSegmentedControlTitlesWithLiteral() {
        let node = LayoutNode(
            view: UISegmentedControl(),
            expressions: [
                "items": "'foo', 'bar', 'baz'",
            ]
        )
        let expected = ["foo", "bar", "baz"]
        XCTAssertEqual(try node.value(forSymbol: "items") as? NSArray, expected as NSArray)
    }

    func testSetSingleSegmentedControlTitle() {
        let node = LayoutNode(
            view: UISegmentedControl(),
            expressions: [
                "items": "'foo'",
            ]
        )
        let expected = ["foo"]
        XCTAssertEqual(try node.value(forSymbol: "items") as? NSArray, expected as NSArray)
    }

    func testSetSegmentedControlTitlesWithConstant() {
        let items = ["foo", "bar", "baz"]
        let node = LayoutNode(
            view: UISegmentedControl(),
            constants: [
                "items": items,
            ],
            expressions: [
                "items": "items",
            ]
        )
        XCTAssertEqual(try node.value(forSymbol: "items") as? NSArray, items as NSArray)
    }

    func testSetSegmentedControlTitlesWithMixedConstantAndLiteral() {
        let items = ["foo", "bar"]
        let node = LayoutNode(
            view: UISegmentedControl(),
            constants: [
                "items": items,
            ],
            expressions: [
                "items": "items, 'baz', 'quux'",
            ]
        )
        let expected = ["foo", "bar", "baz", "quux"]
        XCTAssertEqual(try node.value(forSymbol: "items") as? NSArray, expected as NSArray)
    }
}
