//
//  StateTests.swift
//  Layout
//
//  Created by Nick Lockwood on 18/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import XCTest
@testable import Layout

class StateTests: XCTestCase {

    struct TestState {
        var foo = 5
        var bar = "baz"
    }

    func testStateDictionary() {
        let node = LayoutNode(state: ["foo": 5, "bar": "baz"])
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 5)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
        node.state = ["foo": 10]
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 10)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
    }

    func testStateStruct() {
        var state = TestState()
        let node = LayoutNode(state: state)
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 5)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
        state.foo = 10
        node.state = state
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 10)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
    }

    func testOptionalDictionary() {
        let dict: [String: Any]? = ["foo": 5, "bar": "baz"]
        let node = LayoutNode(state: dict as Any)
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 5)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
    }

    func testOptionalStruct() {
        var state: TestState? = TestState()
        let node = LayoutNode(state: state as Any)
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 5)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
        state?.foo = 10
        node.state = state! // Force unwrap
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 10)
    }

    func testStateContainingOptionals() {
        let node = LayoutNode(
            view: UILabel(),
            state: [
                "foo": (5 as Int?) as Any,
                "bar": (nil as String?) as Any,
            ],
            expressions: [
                "text": "{foo} {bar}",
            ]
        )
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 5)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, nil)
        XCTAssertEqual(try node.value(forSymbol: "text") as? String, "5 nil")
    }
}
