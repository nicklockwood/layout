//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class TestClass: NSObject {
    @objc static var foo: Double {
        return 5
    }
}

class LayoutExpressionTests: XCTestCase {

    // MARK: Expression parsing

    func testParseExpressionWithoutBraces() {
        let expression = try? parseExpression("4 + 5")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithBraces() {
        let expression = try? parseExpression("{4 + 5}")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithBracesAndWhitespace() {
        let expression = try? parseExpression(" {4 + 5} ")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
    }

    func testParseExpressionWithLeadingGarbage() {
        XCTAssertThrowsError(try parseExpression("foo {4 + 5}"))
    }

    func testParseExpressionWithTrailingGarbage() {
        XCTAssertThrowsError(try parseExpression("{4 + 5} foo"))
    }

    func testParseExpressionWithBracesWithLeadingWhitespace() {
        XCTAssertNoThrow(try parseExpression("{ 4 + 5}"))
    }

    func testParseExpressionWithLeadingWhitespace() {
        XCTAssertNoThrow(try parseExpression(" 4 + 5"))
    }

    func testParseEmptyExpression() {
        XCTAssertNoThrow(try parseExpression(""))
    }

    func testParseExpressionWithEmptyBraces() {
        XCTAssertNoThrow(try parseExpression("{}"))
    }

    func testParseExpressionOpeningBrace() {
        XCTAssertThrowsError(try parseExpression("{"))
    }

    func testParseExpressionWithClosingBrace() {
        XCTAssertThrowsError(try parseExpression("}"))
    }

    func testParseExpressionWithMissingClosingBrace() {
        XCTAssertThrowsError(try parseExpression("{4 + 5"))
    }

    func testParseExpressionWithMissingOpeningBrace() {
        XCTAssertThrowsError(try parseExpression("4 + 5}"))
    }

    func testParseExpressionWithExtraOpeningBrace() {
        XCTAssertThrowsError(try parseExpression("{{4 + 5}"))
    }

    func testParseExpressionWithExtraClosingBrace() {
        XCTAssertThrowsError(try parseExpression("{4 + 5}}"))
    }

    func testParseExpressionWithClosingBraceInQuotes() {
        let expression = try? parseExpression("{'}'}")
        XCTAssertNotNil(expression)
        XCTAssertNil(expression?.error)
    }

    func testParseExpressionWithOpeningBraceInQuotes() {
        let expression = try? parseExpression("{'{'}")
        XCTAssertNotNil(expression)
        XCTAssertNil(expression?.error)
    }

    func testParseExpressionWithBracesInQuotes() {
        let expression = try? parseExpression("{'{foo}'}")
        XCTAssertNotNil(expression)
        XCTAssertNil(expression?.error)
    }

    // MARK: String expression parsing

    func testParseStringExpressionWithoutBraces() {
        let parts = (try? parseStringExpression("4 + 5")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .string(string) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(string, "4 + 5")
    }

    func testParseStringExpressionWithBraces() {
        let parts = (try? parseStringExpression("{4 + 5}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertEqual(expression.symbols, [.infix("+")])
    }

    func testParseStringExpressionWithBracesAndWhitespace() {
        let parts = (try? parseStringExpression(" {4 + 5} ")) ?? []
        guard parts.count == 3 else {
            XCTFail()
            return
        }
        guard case let .string(a) = parts[0], a == " " else {
            XCTFail()
            return
        }
        guard case let .expression(b) = parts[1], b.symbols == [.infix("+")] else {
            XCTFail()
            return
        }
        guard case let .string(c) = parts[2], c == " " else {
            XCTFail()
            return
        }
    }

    func testParseStringExpressionWithMultipleBraces() {
        let parts = (try? parseStringExpression("{4} + {5}")) ?? []
        guard parts.count == 3 else {
            XCTFail()
            return
        }
        guard case let .expression(a) = parts[0], a.symbols == [] else {
            XCTFail()
            return
        }
        guard case let .string(b) = parts[1], b == " + " else {
            XCTFail()
            return
        }
        guard case let .expression(c) = parts[2], c.symbols == [] else {
            XCTFail()
            return
        }
    }

    func testParseEmptyStringExpression() {
        do {
            let parts = try parseStringExpression("")
            XCTAssertTrue(parts.isEmpty)
        } catch {
            XCTFail()
        }
    }

    func testParseStringExpressionWithEmptyBraces() {
        XCTAssertNoThrow(try parseStringExpression("{}"))
    }

    func testParseStringExpressionOpeningBrace() {
        XCTAssertThrowsError(try parseStringExpression("{"))
    }

    func testParseStringExpressionClosingBrace() {
        XCTAssertThrowsError(try parseStringExpression("}"))
    }

    func testParseStringExpressionWithMissingClosingBrace() {
        XCTAssertThrowsError(try parseStringExpression("{4 + 5"))
    }

    func testParseStringExpressionWithMissingOpeningBrace() {
        XCTAssertThrowsError(try parseStringExpression("4 + 5}"))
    }

    func testParseStringExpressionWithExtraOpeningBrace() {
        XCTAssertThrowsError(try parseStringExpression("{{4 + 5}"))
    }

    func testParseStringExpressionWithExtraClosingBrace() {
        XCTAssertThrowsError(try parseStringExpression("{4 + 5}}"))
    }

    func testParseStringExpressionWithClosingBraceInQuotes() {
        let parts = (try? parseStringExpression("{'}'}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNil(expression.error)
    }

    func testParseStringExpressionWithOpeningBraceInQuotes() {
        let parts = (try? parseStringExpression("{'{'}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNil(expression.error)
    }

    func testParseStringExpressionWithBracesInQuotes() {
        let parts = (try? parseStringExpression("{'{foo}'}")) ?? []
        XCTAssertEqual(parts.count, 1)
        guard let part = parts.first, case let .expression(expression) = part else {
            XCTFail()
            return
        }
        XCTAssertNil(expression.error)
    }

    // MARK: Expression comments

    func testParseExpressionWithCommentWithoutBraces() {
        let expression = try? parseExpression("4 + 5 // hello")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
        XCTAssertEqual(expression?.description, "4 + 5 // hello")
    }

    func testCommentedOutExpressionWithoutBraces() {
        let expression = try? parseExpression(" //4 + 5")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.isEmpty, true)
        XCTAssertEqual(expression?.description, "// 4 + 5")
    }

    func testParseExpressionWithCommentWithBraces() {
        let expression = try? parseExpression("{4 + 5 // hello}")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.symbols, [.infix("+")])
        XCTAssertEqual(expression?.description, "4 + 5 // hello")
    }

    func testCommentedOutExpressionWithBraces() {
        let expression = try? parseExpression("{ //4 + 5}")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.isEmpty, true)
        XCTAssertEqual(expression?.description, "// 4 + 5")
    }

    func testParseExpressionWithCommentBeforeBraces() {
        let expression = try? parseExpression(" //{4 + 5}")
        XCTAssertNotNil(expression)
        XCTAssertEqual(expression?.isEmpty, true)
        XCTAssertEqual(expression?.description, "// {4 + 5}")
    }

    func testParseStringExpressionWithComment() {
        guard let parts = try? parseStringExpression("foo {4 + 5 // hello } bar") else {
            XCTFail()
            return
        }
        guard parts.count == 3 else {
            XCTFail()
            return
        }
        guard case .string("foo ") = parts[0] else {
            XCTFail()
            return
        }
        guard case let .expression(expression) = parts[1] else {
            XCTFail()
            return
        }
        XCTAssertEqual(expression.symbols, [.infix("+")])
        XCTAssertEqual(expression.description, "4 + 5 // hello")
        XCTAssertNil(expression.error)
        guard case .string(" bar") = parts[2] else {
            XCTFail()
            return
        }
    }

    func testCommentedOutStringExpression() {
        guard let parts = try? parseStringExpression(" //hello {'world'}") else {
            XCTFail()
            return
        }
        guard parts.count == 1 else {
            XCTFail()
            return
        }
        guard case let .comment(comment) = parts[0] else {
            XCTFail()
            return
        }
        XCTAssertEqual(comment, "hello {'world'}")
        XCTAssertEqual(parts[0].description, "// hello {'world'}")
    }

    // MARK: Class properties

    func testClassPropertyInDoubleExpression() {
        let node = LayoutNode()
        let className = NSStringFromClass(TestClass.self)
        let expression = LayoutExpression(doubleExpression: "\(className).foo", for: node)
        XCTAssertEqual(try expression?.evaluate() as? Double, 5)
    }

    func testUIColorPropertyInColorExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(colorExpression: "UIColor.red", for: node)
        XCTAssertEqual(try expression?.evaluate() as? UIColor, .red)
    }

    func testEnumPropertyInEnumExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(enumExpression: "UIViewContentMode.center", type: .uiViewContentMode, for: node)
        XCTAssertEqual(try expression?.evaluate() as? UIViewContentMode, .center)
    }

    func testOptionSetPropertyInEnumExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(optionsExpression: "UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight", type: .uiViewAutoresizing, for: node)
        XCTAssertEqual(try expression?.evaluate() as? UIViewAutoresizing, [.flexibleWidth, .flexibleHeight])
    }

    // MARK: Integration tests

    func testOptionalBracesInNumberExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(doubleExpression: "{4 + 5}", for: node)
        XCTAssertEqual(try expression?.evaluate() as? Double, 9)
    }

    func testOptionalBracesInColorExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(colorExpression: "{white}", for: node)
        XCTAssertEqual(try expression?.evaluate() as? UIColor, .white)
    }

    func testOptionalMultipleExpressionBodiesDisallowedInNumberExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(doubleExpression: "{5}{6}", for: node)
        XCTAssertThrowsError(try expression?.evaluate())
    }

    func testFalseTreatedAsConstant() {
        let node = LayoutNode()
        let expression = LayoutExpression(boolExpression: "false", for: node)
        XCTAssertEqual(expression?.symbols.isEmpty, true)
    }

    func testSetLayerContentsWithCGImageConstant() {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        let image: AnyObject = UIGraphicsGetImageFromCurrentImageContext()!.cgImage!
        UIGraphicsEndImageContext()
        let node = LayoutNode(
            constants: ["image": image],
            expressions: ["layer.contents": "{image}"]
        )
        node.update()
        XCTAssertTrue(node.view.layer.contents as AnyObject === image)
    }

    func testSetLayerContentsWithUIImageConstant() {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        let node = LayoutNode(
            constants: ["image": image],
            expressions: ["layer.contents": "{image}"]
        )
        node.update()
        XCTAssertTrue(node.view.layer.contents as AnyObject === image.cgImage as AnyObject)
    }

    func testSetLayerShadowPathWithConstant() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        let node = LayoutNode(
            constants: ["path": path],
            expressions: ["layer.shadowPath": "path"]
        )
        node.update()
        XCTAssertEqual(node.view.layer.shadowPath, path)
    }

    func testThrowErrorForConstantExpression() {
        let node = LayoutNode(
            constants: ["foo": "Not a color"],
            expressions: ["backgroundColor": "{foo}"]
        )
        node.update()
        XCTAssertThrowsError(try node.throwUnhandledError())
    }

    func testCommentedOutBoolExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(boolExpression: "// false", for: node)
        XCTAssertNil(expression)
    }

    func testCommentedOutColorExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(colorExpression: "// red", for: node)
        XCTAssertNil(expression)
    }

    func testCommentedOutImageExpression() {
        let node = LayoutNode()
        let expression = LayoutExpression(colorExpression: "// MyImage.png", for: node)
        XCTAssertNil(expression)
    }

    func testBoolExpressionWithComment() {
        let node = LayoutNode()
        let expression = LayoutExpression(boolExpression: "false // comment", for: node)
        XCTAssertNotNil(expression)
        XCTAssertEqual(try! expression?.evaluate() as? Bool, false)
    }

    func testColorExpressionWithComment() {
        let node = LayoutNode()
        let expression = LayoutExpression(colorExpression: "red // comment", for: node)
        XCTAssertNotNil(expression)
        XCTAssertEqual(try! expression?.evaluate() as? UIColor, .red)
    }

    func testImageExpressionWithComment() { // Not supported
        let node = LayoutNode()
        let expression = LayoutExpression(colorExpression: "MyImage.png // comment", for: node)
        XCTAssertNotNil(expression)
        XCTAssertThrowsError(try expression?.evaluate())
    }
}
