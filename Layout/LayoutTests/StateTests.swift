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
        XCTAssertThrowsError(try node.value(forSymbol: "text")) { error in
            XCTAssert("\(error)".contains("nil"))
        }
    }

    class TestVC: UIViewController {
        var updated = false

        override func didUpdateLayout(for node: LayoutNode) {
            updated = true
        }
    }

    func testStateDictionaryUpdates() {
        let node = LayoutNode(state: ["foo": 5, "bar": "baz"], expressions: ["top": "foo"])
        let vc = TestVC()
        try! node.mount(in: vc)
        XCTAssertTrue(vc.updated)
        vc.updated = false
        node.state = ["foo": 6, "bar": "baz"] // Changed
        XCTAssertTrue(vc.updated)
        vc.updated = false
        node.state = ["foo": 6, "bar": "baz"] // Not changed
        XCTAssertFalse(vc.updated)
    }

    func testStateStructUpdates() {
        var state = TestState()
        let node = LayoutNode(state: state, expressions: ["top": "foo"])
        let vc = TestVC()
        try! node.mount(in: vc)
        XCTAssertTrue(vc.updated)
        vc.updated = false
        state.foo = 6
        node.state = state // Changed
        XCTAssertTrue(vc.updated)
        vc.updated = false
        node.state = state // Not changed
        XCTAssertFalse(vc.updated)
    }
}
