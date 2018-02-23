//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class AttributedStringExpressionTests: XCTestCase {
    func testAttributedStringExpressionTextAndFont() {
        let node = LayoutNode()
        let expression = LayoutExpression(attributedStringExpression: "foo", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        XCTAssertEqual(result.string, "foo")
        XCTAssertEqual(result.attribute(NSAttributedStringKey.font, at: 0, effectiveRange: nil) as? UIFont, .systemFont(ofSize: 17))
    }

    func testAttributedStringHTMLExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(attributedStringExpression: "<b>foo</b>", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        XCTAssertEqual(result.string, "foo")
        XCTAssertEqual(result.attribute(NSAttributedStringKey.font, at: 0, effectiveRange: nil) as? UIFont, .boldSystemFont(ofSize: 17))
    }

    func testAttributedStringContainingUnicode() {
        let node = LayoutNode()
        let text = "🤔😂"
        let expression = LayoutExpression(attributedStringExpression: "<i>\(text)</i>", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        XCTAssertEqual(result.string, text)
    }

    func testAttributedStringInheritsFont() {
        let label = UILabel()
        label.font = UIFont(name: "Courier", size: 57)
        let node = LayoutNode(view: label)
        let expression = LayoutExpression(attributedStringExpression: "foo", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        XCTAssertEqual(result.attribute(NSAttributedStringKey.font, at: 0, effectiveRange: nil) as? UIFont, label.font)
    }

    func testAttributedStringInheritsTextColor() {
        let label = UILabel()
        label.textColor = .red
        let node = LayoutNode(view: label)
        let expression = LayoutExpression(attributedStringExpression: "foo", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        XCTAssertEqual(result.attribute(NSAttributedStringKey.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
    }

    func testAttributedStringInheritsTextAlignment() {
        let label = UILabel()
        label.textAlignment = .right
        let node = LayoutNode(view: label)
        let expression = LayoutExpression(attributedStringExpression: "foo", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        let paragraphStyle = result.attribute(NSAttributedStringKey.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        XCTAssertEqual(paragraphStyle.alignment, .right)
    }

    func testAttributedStringInheritsLinebreakMode() {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingHead
        let node = LayoutNode(view: label)
        let expression = LayoutExpression(attributedStringExpression: "foo", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        let paragraphStyle = result.attribute(NSAttributedStringKey.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        XCTAssertEqual(paragraphStyle.lineBreakMode, .byTruncatingHead)
    }

    func testAttributedStringContainingToken() {
        let node = LayoutNode(constants: ["bar": NSAttributedString(string: "bar")])
        let expression = LayoutExpression(attributedStringExpression: "hello $(0) world {bar}", for: node)
        let result = try! expression?.evaluate() as! NSAttributedString
        XCTAssertEqual(result.string, "hello $(0) world bar")
    }
}
