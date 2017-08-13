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

    func testViewInsideHTMLInsideLabel() {
        let input = "<UILabel><p><UIView/></p></UILabel>"
        XCTAssertThrowsError(try Layout(xmlData: input.data(using: .utf8)!)) { error in
            guard let layoutError = error as? LayoutError else {
                XCTFail("\(error)")
                return
            }
            XCTAssertTrue("\(layoutError)".contains("Unsupported HTML"))
            XCTAssertTrue("\(layoutError)".contains("UIView"))
        }
    }

    func testInvalidHTML() {
        let input = "<UILabel>Some <bold>bold</bold> text</UILabel>"
        let xmlData = input.data(using: .utf8)!
        XCTAssertThrowsError(try Layout(xmlData: xmlData)) { error in
            XCTAssert("\(error)".contains("bold"))
        }
    }
}
