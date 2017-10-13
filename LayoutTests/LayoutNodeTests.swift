//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

private class TestView: UIView {
    var wasUpdated = false
    @objc var testProperty = "" {
        didSet {
            wasUpdated = true
        }
    }
}

class LayoutNodeTests: XCTestCase {

    // MARK: Expression errors

    func testInvalidExpression() {
        let node = LayoutNode(expressions: ["foobar": "5"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("Unknown property") == true)
        XCTAssertTrue(errors.first?.description.contains("foobar") == true)
    }

    func testReadOnlyExpression() {
        let node = LayoutNode(expressions: ["safeAreaInsets.top": "5"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("read-only") == true)
        XCTAssertTrue(errors.first?.description.contains("safeAreaInsets.top") == true)
    }

    func testCircularReference1() {
        let node = LayoutNode(expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("reference") == true)
        XCTAssertTrue(errors.first?.description.contains("top") == true)
    }

    func testCircularReference2() {
        let node = LayoutNode(expressions: ["top": "bottom", "bottom": "top"])
        let errors = node.validate()
        XCTAssertGreaterThanOrEqual(errors.count, 2)
        for error in errors {
            let description = error.description
            XCTAssertTrue(description.contains("reference"))
            XCTAssertTrue(description.contains("top") || description.contains("bottom"))
        }
    }

    func testCircularReference3() {
        UIGraphicsBeginImageContext(CGSize(width: 20, height: 10))
        let node = LayoutNode(
            expressions: [
                "height": "auto",
                "width": "100%",
            ],
            children: [
                LayoutNode(
                    view: UIImageView(image: UIGraphicsGetImageFromCurrentImageContext()),
                    expressions: [
                        "width": "max(auto, height)",
                        "height": "max(auto, width)",
                    ]
                ),
            ]
        )
        UIGraphicsEndImageContext()
        let errors = node.validate()
        XCTAssertGreaterThanOrEqual(errors.count, 2)
        for error in errors {
            let description = error.description
            XCTAssertTrue(description.contains("reference"))
            XCTAssertTrue(description.contains("width") || description.contains("height"))
        }
    }

    // Animated setter

    func testSetSwitchStateAnimated() {
        let view = UISwitch()
        let node = LayoutNode(view: view, state: ["onState": false], expressions: ["isOn": "onState"])
        XCTAssertFalse(view.isOn)
        node.setState(["onState": true], animated: true)
        XCTAssertTrue(view.isOn)
    }

    func testScrollViewZoomScaleAnimated() {
        let view = UIScrollView()
        let node = LayoutNode(view: view, state: ["zoom": 1], expressions: [
            "zoomScale": "zoom",
        ])
        node.setState(["zoom": 2], animated: true)
    }

    func testScrollViewContentOffsetAnimated() {
        let view = UIScrollView()
        let node = LayoutNode(view: view, state: ["offset": CGPoint.zero], expressions: [
            "contentOffset": "offset",
            "contentSize.height": "100",
        ])
        let expected = CGPoint(x: 0, y: 15)
        XCTAssertEqual(view.contentOffset, .zero)
        node.setState(["offset": expected], animated: true)
        XCTAssertEqual(view.contentOffset, expected)
    }

    // MARK: Property errors

    func testNonexistentViewProperty() {
        let node = LayoutNode(view: UIView(), expressions: ["width": "5 + layer.foobar"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("Unknown property") == true)
        XCTAssertTrue(errors.first?.description.contains("foobar") == true)
    }

    func testNestedNonexistentViewProperty() {
        let node = LayoutNode(view: UIView(), expressions: ["width": "5 + layer.foo.bar"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("Unknown property") == true)
        XCTAssertTrue(errors.first?.description.contains("foo.bar") == true)
    }

    func testNonexistentRectViewProperty() {
        let node = LayoutNode(view: UIView(), expressions: ["width": "5 + frame.foo.bar"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("Unknown property") == true)
        XCTAssertTrue(errors.first?.description.contains("foo.bar") == true)
    }

    func testNilViewProperty() {
        let node = LayoutNode(view: UIView(), expressions: ["width": "layer.contents == nil ? 5 : 10"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 0)
        node.update()
        XCTAssertNil(node.view.layer.contents)
        XCTAssertEqual(node.view.frame.width, 5)
    }

    // MARK: State/constant/parameter shadowing

    func testExpressionShadowsConstant() {
        let node = LayoutNode(constants: ["top": 10], expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "top"), 10)
    }

    func testExpressionShadowsVariable() {
        let node = LayoutNode(state: ["top": 10], expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "top"), 10)
    }

    func testStateShadowsConstant() {
        let node = LayoutNode(state: ["foo": 10], constants: ["foo": 5], expressions: ["top": "foo"])
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "foo"), 10)
        XCTAssertEqual(try node.doubleValue(forSymbol: "top"), 10)
    }

    func testConstantShadowsViewProperty() {
        let view = UIView()
        view.tag = 10
        let node = LayoutNode(view: view, constants: ["tag": 5])
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "tag"), 5)
    }

    func testStateShadowsInheritedConstant() {
        let child = LayoutNode(state: ["foo": 10], expressions: ["top": "foo"])
        let parent = LayoutNode(constants: ["foo": 5], children: [child])
        XCTAssertTrue(parent.validate().isEmpty)
        XCTAssertEqual(try child.doubleValue(forSymbol: "foo"), 10)
        XCTAssertEqual(try child.doubleValue(forSymbol: "top"), 10)
    }

    func testConstantShadowsInheritedState() {
        let child = LayoutNode(constants: ["foo": 10], expressions: ["top": "foo"])
        let parent = LayoutNode(state: ["foo": 5], children: [child])
        XCTAssertTrue(parent.validate().isEmpty)
        XCTAssertEqual(try child.doubleValue(forSymbol: "foo"), 10)
        XCTAssertEqual(try child.doubleValue(forSymbol: "top"), 10)
    }

    func testParameterNameShadowsState() {
        let xmlData = "<UILabel text=\"{name}\" name=\"{name}\"><param name=\"name\" type=\"String\"/></UILabel>".data(using: .utf8)!
        let node = try! LayoutNode.with(xmlData: xmlData)
        node.setState(["name": "Foo"])
        node.update()
        XCTAssertEqual((node.view as! UILabel).text, "Foo")
    }

    func testMacroNameShadowsState() {
        let xmlData = "<UIView name=\"{foo}\"><macro name=\"name\" value=\"name\"/><UILabel text=\"{name}\"/></UIView>".data(using: .utf8)!
        let node = try! LayoutNode.with(xmlData: xmlData)
        node.setState(["name": "Foo"])
        node.update()
        XCTAssertEqual((node.view.subviews[0] as! UILabel).text, "Foo")
    }

    // MARK: update(with:)

    func testUpdateViewWithSameClass() {
        let node = LayoutNode(view: UIView())
        let oldView = node.view
        XCTAssertTrue(oldView.classForCoder == UIView.self)
        let layout = Layout(node)
        try! node.update(with: layout)
        XCTAssertTrue(oldView === node.view)
    }

    func testUpdateViewWithSubclass() {
        let node = LayoutNode(view: UIView())
        XCTAssertTrue(node.view.classForCoder == UIView.self)
        let layout = Layout(LayoutNode(view: UILabel()))
        try! node.update(with: layout)
        XCTAssertTrue(node.view.classForCoder == UILabel.self)
    }

    func testUpdateViewWithSuperclass() {
        let node = LayoutNode(view: UILabel())
        let layout = Layout(LayoutNode(view: UIView()))
        XCTAssertThrowsError(try node.update(with: layout))
    }

    func testUpdateViewControllerWithSameClass() {
        let node = LayoutNode(viewController: UIViewController())
        let oldViewController = node.viewController
        XCTAssertTrue(oldViewController?.classForCoder == UIViewController.self)
        let layout = Layout(node)
        try! node.update(with: layout)
        XCTAssertTrue(oldViewController === node.viewController)
    }

    func testUpdateViewControllerWithSubclass() {
        let node = LayoutNode(viewController: UIViewController())
        XCTAssertTrue(node.viewController?.classForCoder == UIViewController.self)
        let layout = Layout(LayoutNode(viewController: UITabBarController()))
        try! node.update(with: layout)
        XCTAssertTrue(node.viewController?.classForCoder == UITabBarController.self)
    }

    func testUpdateViewControllerWithSuperclass() {
        let node = LayoutNode(viewController: UITabBarController())
        let layout = Layout(LayoutNode(viewController: UIViewController()))
        XCTAssertThrowsError(try node.update(with: layout))
    }

    // MARK: value persistence

    func testLiteralValueNotReapplied() {
        let view = TestView()
        let node = LayoutNode(view: view, expressions: ["testProperty": "foo"])

        node.update()
        XCTAssertTrue(view.wasUpdated)
        XCTAssertEqual(view.testProperty, "foo")

        view.wasUpdated = false
        node.update()
        XCTAssertFalse(view.wasUpdated)

        view.testProperty = "bar"
        node.update()
        XCTAssertEqual(view.testProperty, "bar")
    }

    func testConstantValueNotReapplied() {
        let view = TestView()
        let node = LayoutNode(view: view, constants: ["foo": "foo"], expressions: ["testProperty": "{foo}"])

        node.update()
        XCTAssertTrue(view.wasUpdated)
        XCTAssertEqual(view.testProperty, "foo")

        view.wasUpdated = false
        node.update()
        XCTAssertFalse(view.wasUpdated)

        view.testProperty = "bar"
        node.update()
        XCTAssertEqual(view.testProperty, "bar")
    }

    func testUnchangedValueNotReapplied() {
        let view = TestView()
        let node = LayoutNode(view: view, state: ["text": "foo"], expressions: ["testProperty": "{text}"])

        node.update()
        XCTAssertTrue(view.wasUpdated)
        XCTAssertEqual(view.testProperty, "foo")

        view.wasUpdated = false
        node.update()
        XCTAssertFalse(view.wasUpdated)
    }

    // MARK: property evaluation order

    func testUpdateContentInsetWithTop() {
        let scrollView = UIScrollView()
        let node = LayoutNode(
            view: scrollView,
            state: [
                "inset": UIEdgeInsets.zero,
                "insetTop": 5,
            ],
            expressions: [
                "contentInset": "inset",
                "contentInset.top": "insetTop",
            ]
        )

        node.update()
        XCTAssertEqual(scrollView.contentInset.top, 5)
    }

    func testUpdateContentInsetWithConstantTop() {
        let scrollView = UIScrollView()
        let node = LayoutNode(
            view: scrollView,
            state: ["inset": UIEdgeInsets.zero],
            expressions: [
                "contentInset": "inset",
                "contentInset.top": "5",
            ]
        )

        node.update()
        XCTAssertEqual(scrollView.contentInset.top, 5)
    }

    // MARK: memory leaks

    func testLayoutNodeWithSelfReferencingExpressionIsReleased() {
        weak var node: LayoutNode?
        do {
            let strongNode = LayoutNode(
                view: UIView(),
                expressions: [
                    "top": "safeAreaInsets.top",
                ]
            )
            strongNode.update()
            node = strongNode
        }
        XCTAssertNil(node)
    }
}
