//
//  FormatTests.swift
//  LayoutToolTests
//
//  Created by Nick Lockwood on 29/06/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import XCTest

class FormatTests: XCTestCase {

    // MARK: Attributes

    func testNoAttributes() {
        let input = "<Foo/>"
        let output = "<Foo/>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testMultipleAttributes() {
        let input = "<Foo bar=\"baz\" baz=\"quux\" />"
        let output = "<Foo\n    bar=\"baz\"\n    baz=\"quux\"\n/>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testSortAttributes() {
        let input = "<Foo b=\"b\" c=\"c\" a=\"a\"/>"
        let output = "<Foo\n    a=\"a\"\n    b=\"b\"\n    c=\"c\"\n/>\n"
        XCTAssertEqual(try format(input), output)
    }

    // MARK: Children

    func testEmptyNode() {
        let input = "<Foo>\n</Foo>"
        let output = "<Foo/>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testWhiteSpaceAroundNodeWithNoAttributes() {
        let input = "<Foo> <Bar/> </Foo>"
        let output = "<Foo>\n    <Bar/>\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testWhiteSpaceAroundNodeWithMultipleAttributes() {
        let input = "<Foo\n    bar=\"bar\"\n    baz=\"baz\"> <Bar/> </Foo>"
        let output = "<Foo\n    bar=\"bar\"\n    baz=\"baz\">\n\n    <Bar/>\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    // MARK: Text

    func testShortTextNode() {
        let input = "<Foo>\n    bar\n</Foo>"
        let output = "<Foo>bar</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testTextWithCommentBefore() {
        let input = "<Foo><!-- bar -->bar</Foo>"
        let output = "<Foo>\n\n    <!-- bar -->\n    bar\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testTextWithCommentAfter() {
        let input = "<Foo>bar<!-- bar --></Foo>"
        let output = "<Foo>\n    bar\n\n    <!-- bar -->\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testTextWithInterleavedComments() {
        let input = "<Foo><!-- bar -->bar<!-- baz -->baz</Foo>"
        let output = "<Foo>\n\n    <!-- bar -->\n    bar\n\n    <!-- baz -->\n    baz\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    // MARK: HTML

    func testNoTrimSpaceInHTML() {
        let input = "<Foo>hello<span> world</span></Foo>"
        let output = "<Foo>\n    hello<span> world</span>\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testIndentList() {
        let input = "<ul><li>foo</li><li>bar</li></ul>"
        let output = "<ul>\n    <li>foo</li>\n    <li>bar</li>\n</ul>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testPreserveListIndenting() {
        let input = "<ul>\n    <li>foo</li>\n    <li>bar</li>\n</ul>"
        let output = "<ul>\n    <li>foo</li>\n    <li>bar</li>\n</ul>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testIndentMultilineText() {
        let input = "<Foo><p>foo\nbar</p></Foo>"
        let output = "<Foo>\n    <p>foo\n    bar</p>\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testPreserveMultilineTextIndent() {
        let input = "<Foo>\n    <p>\n        foo\n        <b>bar</b> baz\n    </p>\n</Foo>"
        let output = "<Foo>\n    <p>\n        foo\n        <b>bar</b> baz\n    </p>\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    // MARK: Comments

    func testLeadingComment() {
        let input = "<!-- foo --><Foo/>"
        let output = "<!-- foo -->\n<Foo/>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testInnerComment() {
        let input = "<Foo><!-- foo --></Foo>"
        let output = "<Foo><!-- foo --></Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testNoMultipleLinebreaksBetweenNodeAndComment() {
        let input = "<Foo>\n\n    <Bar/>\n\n    <!-- baz -->\n    <Baz/>\n\n</Foo>"
        let output = "<Foo>\n    <Bar/>\n\n    <!-- baz -->\n    <Baz/>\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testNoMultipleLinebreaksAfterAttributesBeforeComment() {
        let input = "<Foo\n    bar=\"bar\"\n    baz=\"baz\">\n\n    <!-- bar -->\n    <Bar/>\n\n</Foo>"
        let output = "<Foo\n    bar=\"bar\"\n    baz=\"baz\">\n\n    <!-- bar -->\n    <Bar/>\n</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    // MARK: Encoding

    func testEncodeAmpersandInText() {
        let input = "<Foo>bar &amp; baz</Foo>"
        let output = "<Foo>bar &amp; baz</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testNoEncodeDoubleQuoteInText() {
        let input = "<Foo>\"bar\"</Foo>"
        let output = "<Foo>\"bar\"</Foo>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testEncodeAmpersandInAttribute() {
        let input = "<Foo\n    bar=\"baz &amp; quux\"\n    baz=\"baz\"\n/>"
        let output = "<Foo\n    bar=\"baz &amp; quux\"\n    baz=\"baz\"\n/>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testEncodeDoubleQuoteInAttribute() {
        let input = "<Foo\n    bar=\"&quot;bar&quot;\"\n    baz=\"baz\"\n/>"
        let output = "<Foo\n    bar=\"&quot;bar&quot;\"\n    baz=\"baz\"\n/>\n"
        XCTAssertEqual(try format(input), output)
    }

    func testNoEncodeCommentBody() {
        let input = "<!-- <Foo>\"bar & baz\"</Foo> --><Bar/>"
        let output = "<!-- <Foo>\"bar & baz\"</Foo> -->\n<Bar/>\n"
        XCTAssertEqual(try format(input), output)
    }
}
