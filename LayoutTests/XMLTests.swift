//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class XMLTests: XCTestCase {

    // MARK: Malformed XML

    func testViewInsideHTML() {
        let input = "<p><UIView/></p>"
        XCTAssertThrowsError(try Layout(xmlData: input.data(using: .utf8)!)) { error in
            XCTAssert("\(error)".contains("p"))
        }
    }

    func testViewInsideHTMLInsideView() {
        let input = "<UIView><p><UIView/></p></UIView>"
        do {
            let layout = try Layout(xmlData: input.data(using: .utf8)!)
            let layoutNode = try LayoutNode(layout: layout)
            XCTAssertThrowsError(try layoutNode.update()) { error in
                guard let layoutError = error as? LayoutError else {
                    XCTFail("\(error)")
                    return
                }
                XCTAssertTrue("\(layoutError)".contains("Unknown expression name `text`"))
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testInvalidHTML() {
        let input = "<UILabel>Some <bold>bold</bold> text</UILabel>"
        let layout = try! Layout(xmlData: input.data(using: .utf8)!)
        XCTAssertThrowsError(try LayoutNode(layout: layout)) { error in
            XCTAssert("\(error)".contains("bold"))
        }
    }
}
