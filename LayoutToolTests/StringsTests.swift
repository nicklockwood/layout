//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest

class StringsTests: XCTestCase {

    func testFindStringsInAttributes() {
        let input = "<UILabel text=\"{strings.foo} {strings.bar}\"/>"
        let output = ["bar", "foo"]
        XCTAssertEqual(try strings(in: input), output)
    }

    func testFindStringsInBody() {
        let input = "<UILabel>{strings.foo} {strings.bar}</UILabel>"
        let output = ["bar", "foo"]
        XCTAssertEqual(try strings(in: input), output)
    }

    func testIgnoreDuplicateStrings() {
        let input = "<UILabel>{strings.foo} {strings.bar} {strings.foo}</UILabel>"
        let output = ["bar", "foo"]
        XCTAssertEqual(try strings(in: input), output)
    }

    func testFindEscapedString() {
        let input = "<UILabel text=\"{`strings.hello world`}\"/>"
        let output = ["hello world"]
        XCTAssertEqual(try strings(in: input), output)
    }
}
