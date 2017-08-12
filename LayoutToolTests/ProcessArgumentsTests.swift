//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest

class ProcessArgumentsTests: XCTestCase {

    func testReturnsSuccessCodeForExpectedInput() {
        XCTAssertEqual(processArguments(["LayoutTool", "version"]), .success)
    }

    func testReturnsErrorCodeWhenErrorsOccur() {
        XCTAssertEqual(processArguments(["LayoutTool"]), .error)
        XCTAssertEqual(processArguments(["LayoutTool", "format"]), .error)
    }
    
}
