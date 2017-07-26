//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest

class RenameTests: XCTestCase {

    func testRenameStandaloneVariable() {
        let input = "<Foo bar=\"foo\"/>"
        let expected = "<Foo bar=\"bar\"/>\n"
        let output = try! rename("foo", to: "bar", in: input)
        XCTAssertEqual(output, expected)
    }

    func testRenameVariableInExpression() {
        let input = "<Foo bar=\"(foo + bar) * 5\"/>"
        let expected = "<Foo bar=\"(bar + bar) * 5\"/>\n"
        let output = try! rename("foo", to: "bar", in: input)
        XCTAssertEqual(output, expected)
    }

    func testNoRenameTextInStringExpression() {
        let input = "<Foo title=\"foo + bar\"/>"
        let expected = "<Foo title=\"foo + bar\"/>\n"
        let output = try! rename("foo", to: "bar", in: input)
        XCTAssertEqual(output, expected)
    }

    func testRenameVariableInEscapedStringExpression() {
        let input = "<Foo title=\"{foo + bar}\"/>"
        let expected = "<Foo title=\"{bar + bar}\"/>\n"
        let output = try! rename("foo", to: "bar", in: input)
        XCTAssertEqual(output, expected)
    }
}
