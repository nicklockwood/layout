//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

private let nodeCount = 200

class PerformanceTests: XCTestCase {

    private func createNodes(_ count: Int) -> LayoutNode {
        var children = [LayoutNode]()
        for i in 0 ..< count {
            children.append(
                LayoutNode(
                    view: UILabel(),
                    expressions: [
                        "top": "previous.bottom + 10",
                        "left": "10",
                        "width": "100% - 20",
                        "height": "auto",
                        "font": "helvetica body italic",
                        "text": "\(i). Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                    ]
                )
            )
        }
        return LayoutNode(
            expressions: [
                "width": "100%",
                "height": "auto",
            ],
            children: children
        )
    }

    func testCreation() {
        measure {
            _ = self.createNodes(nodeCount)
        }
    }

    func testMount() {
        let rootNode = createNodes(nodeCount)
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        measure {
            try! rootNode.mount(in: view)
            rootNode.unmount()
        }
    }

    func testCreateAndMount() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        measure {
            let rootNode = self.createNodes(nodeCount)
            try! rootNode.mount(in: view)
            rootNode.unmount()
        }
    }

    func testUpdate() {
        let rootNode = createNodes(nodeCount)
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        try! rootNode.mount(in: view)
        measure {
            view.frame.size = CGSize(width: 200, height: 500)
            try! rootNode.update()
        }
    }
}
