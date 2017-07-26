//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

private class TestView: UIView {
    var action: Selector?
}

private class TestViewController: UIViewController {
    func foo(_ sender: UIView) {
        print("It works!")
    }
}

class SelectorExpressionTests: XCTestCase {

    func testSetControlAction() {
        let node = LayoutNode(view: UIControl(), expressions: ["touchUpInside": "foo:"])
        let viewController = TestViewController()
        XCTAssertNoThrow(try node.mount(in: viewController))
        let control = node.view as! UIControl
        XCTAssertEqual(control.actions(forTarget: viewController, forControlEvent: .touchUpInside)?.first, "foo:")
    }

    func testSetCustomSelector() {
        let node = LayoutNode(view: TestView(), expressions: ["action": "foo:"])
        XCTAssertNoThrow(try node.update())
        XCTAssertNotNil(node.view.action)
    }
}
