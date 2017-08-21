//  Copyright © 2017 Schibsted. All rights reserved.

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
        node.setState(["foo": 10])
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 10)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
    }

    func testNestedStateDictionary() {
        let node = LayoutNode(state: ["foo": ["bar": "baz"]])
        XCTAssertEqual(try node.value(forSymbol: "foo") as! [String: String], ["bar": "baz"])
        XCTAssertEqual(try node.value(forSymbol: "foo.bar") as? String, "baz")
    }

    func testStateStruct() {
        var state = TestState()
        let node = LayoutNode(state: state)
        XCTAssertEqual(try node.value(forSymbol: "foo") as? Int, 5)
        XCTAssertEqual(try node.value(forSymbol: "bar") as? String, "baz")
        state.foo = 10
        node.setState(state)
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
        node.setState(state!) // Force unwrap
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

        override func didUpdateLayout(for _: LayoutNode) {
            updated = true
        }
    }

    func testStateDictionaryUpdates() {
        let node = LayoutNode(state: ["foo": 5, "bar": "baz"], expressions: ["top": "foo"])
        let vc = TestVC()
        try! node.mount(in: vc)
        XCTAssertTrue(vc.updated)
        vc.updated = false
        node.setState(["foo": 6, "bar": "baz"]) // Changed
        XCTAssertTrue(vc.updated)
        vc.updated = false
        node.setState(["foo": 6, "bar": "baz"]) // Not changed
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
        node.setState(state) // Changed
        XCTAssertTrue(vc.updated)
        vc.updated = false
        node.setState(state) // Not changed
        XCTAssertFalse(vc.updated)
    }
}
