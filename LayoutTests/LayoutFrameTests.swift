//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class LayoutFrameTests: XCTestCase {

    // MARK: Frame/view consistency

    func testLayoutFrameMatchesView() {
        let frame = CGRect(x: 100, y: 50, width: 200, height: 300)
        let view = UIView(frame: frame)
        let node = LayoutNode(view: view)

        // Test unmounted view
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)

        // Test mounted view
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        try! node.mount(in: superview)
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)
    }

    func testLayoutFrameSizeMatchesView() {
        let view = UIView(frame: CGRect(x: 100, y: 50, width: 200, height: 300))
        let node = LayoutNode(view: view, expressions: ["left": "5", "top": "15"])
        let expectedFrame = CGRect(x: 5, y: 15, width: 200, height: 300)

        // Test unmounted view
        XCTAssertEqual(view.frame.size, expectedFrame.size)
        XCTAssertEqual(node.frame, expectedFrame)

        // Test mounted view
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        try! node.mount(in: superview)
        XCTAssertEqual(view.frame, expectedFrame)
        XCTAssertEqual(node.frame, view.frame)
    }

    func testLayoutFrameOriginMatchesView() {
        let view = UIView(frame: CGRect(x: 100, y: 50, width: 200, height: 300))
        let node = LayoutNode(view: view, expressions: ["width": "5", "height": "15"])
        let expectedFrame = CGRect(x: 100, y: 50, width: 5, height: 15)

        // Test unmounted view
        XCTAssertEqual(view.frame.origin, expectedFrame.origin)
        XCTAssertEqual(node.frame, expectedFrame)

        // Test mounted view
        let superview = UIView()
        try! node.mount(in: superview)
        XCTAssertEqual(view.frame, expectedFrame)
        XCTAssertEqual(node.frame, view.frame)
    }

    func testLayoutFrameTracksView() {
        var frame = CGRect(x: 100, y: 50, width: 200, height: 300)
        let view = UIView(frame: frame)
        let node = LayoutNode(view: view)
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        superview.addSubview(view)

        // Test initial frame
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)

        // Test updated frame
        frame = CGRect(x: 20, y: 15, width: 150, height: 400)
        view.frame = frame
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)
    }

    // MARK: Auto-sizing

    func testAutoSizeParentToFitChildren() {
        let node = LayoutNode(
            expressions: [
                "width": "auto",
                "height": "auto",
            ],
            children: [
                LayoutNode(
                    expressions: [
                        "width": "100",
                        "height": "20",
                    ]
                ),
                LayoutNode(
                    expressions: [
                        "top": "previous.bottom + 10",
                        "width": "150",
                        "height": "20",
                    ]
                ),
            ]
        )
        XCTAssertEqual(node.frame.size, CGSize(width: 150, height: 50))
    }

    func testAutosizeParentHeightToFitChildren() {
        let node = LayoutNode(
            expressions: [
                "width": "auto",
                "height": "10",
            ],
            children: [
                LayoutNode(
                    expressions: [
                        "width": "100",
                        "height": "20",
                    ]
                ),
                LayoutNode(
                    expressions: [
                        "top": "previous.bottom + 10",
                        "width": "150",
                        "height": "20",
                    ]
                ),
            ]
        )
        XCTAssertEqual(node.frame.size, CGSize(width: 150, height: 10))
    }

    func testAutosizeParentWidthToFitChildren() {
        let node = LayoutNode(
            expressions: [
                "width": "50",
                "height": "auto",
            ],
            children: [
                LayoutNode(
                    expressions: [
                        "width": "100",
                        "height": "20",
                    ]
                ),
                LayoutNode(
                    expressions: [
                        "top": "previous.bottom + 10",
                        "width": "150",
                        "height": "20",
                    ]
                ),
            ]
        )
        XCTAssertEqual(node.frame.size, CGSize(width: 50, height: 50))
    }

    func testAutosizeParentWhenChildHasPercentageWidth() {
        let node = LayoutNode(
            expressions: [
                "width": "auto",
                "height": "auto",
            ],
            children: [
                LayoutNode(
                    expressions: [
                        "width": "50%",
                        "height": "20",
                    ]
                ),
                LayoutNode(
                    expressions: [
                        "top": "previous.bottom + 10",
                        "width": "150",
                        "height": "20",
                    ]
                ),
            ]
        )
        node.update()
        XCTAssertEqual(node.frame.size, CGSize(width: 150, height: 50))
        XCTAssertEqual(node.children[0].frame.size, CGSize(width: 75, height: 20))
    }

    func testAutosizeParentWhenChildHasAutoWidth() {
        let node = LayoutNode(
            expressions: [
                "width": "auto",
                "height": "auto",
            ],
            children: [
                LayoutNode(
                    expressions: [
                        "width": "auto",
                        "height": "20",
                    ]
                ),
                LayoutNode(
                    expressions: [
                        "top": "previous.bottom + 10",
                        "width": "150",
                        "height": "20",
                    ]
                ),
            ]
        )
        node.update()
        XCTAssertEqual(node.frame.size, CGSize(width: 150, height: 50))
        XCTAssertEqual(node.children[0].frame.size, CGSize(width: 150, height: 20))
    }
}
