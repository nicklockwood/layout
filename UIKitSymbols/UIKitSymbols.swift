//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
import UIKit
import GLKit
import AVKit
import SceneKit
import SpriteKit
import MapKit
import WebKit

@testable import Layout

class UIKitSymbols: XCTestCase {

    func getProperties() -> [String: [String: RuntimeType]] {

        // Force classes to load
        _ = AVPlayerViewController()
        _ = WKWebView()

        // Get class names
        var classCount: UInt32 = 0
        let classes = objc_copyClassList(&classCount)
        var names = ["SKView"] // Doesn't load otherwise for some reason
        for cls in UnsafeBufferPointer(start: classes, count: Int(classCount)) {
            if let cls = cls, class_getSuperclass(cls) != nil,
                class_conformsToProtocol(cls, NSObjectProtocol.self),
                cls.isSubclass(of: UIView.self) || cls.isSubclass(of: UIViewController.self) {
                let name = NSStringFromClass(cls)
                if !name.hasPrefix("_"), !name.contains(".") {
                    names.append(name)
                }
            }
        }

        // Filter views
        let whitelist = [
            "AVPlayerViewController",
            "AVPictureInPictureViewController",
            "MKOverlay",
            "MKMapView",
            "GLK",
            "SCNView",
            "SKView",
            "UI",
            "WKWebView",
        ]
        let blacklist = [
            "UIActionSheet",
            "UIActivityGroupViewController",
            "UICompatibilityInputViewController",
            "UICoverSheetButton",
            "UIDebugging",
            "UIDefaultKeyboardInput",
            "UIDictation",
            "UIDimmingView",
            "UIDocumentPasswordView",
            "UIDocumentSharingController",
            "UIDynamicCaret",
            "UIFieldEditor",
            "UIInputSetContainerView",
            "UIInputWindowController",
            "UIInterfaceActionGroupView",
            "UIInterfaceActionRepresentationView",
            "UIKB",
            "UIKeyCommand",
            "UIKeyboard",
            "UIMoreListController",
            "UIMovieScrubber",
            "UIPasscodeField",
            "UIPickerColumnView",
            "UIPickerTableView",
            "UIPrint",
            "UIReferenceLibraryViewController",
            "UIRemoteKeyboardWindow",
            "UISearchBarBackground",
            "UISearchBarTextField",
            "UISnapshotView",
            "UIStatusBar",
            "UISwitchModernVisualElement",
            "UISystemInputViewController",
            "UITabBarButton",
            "UITableViewCellContentView",
            "UITableViewCellFocusableReorderControl",
            "UITableViewIndexOverlaySelectionView",
            "UITextAttachmentView",
            "UITextContentView",
            "UITextEffectsWindow",
            "UIWebBrowserView",
            "UIWebDocumentView",
            "UIWebFileUploadPanel",
            "UIWebPDFView",
            "UIWebPlaybackTargetPicker",
            "UIWebSelect",
            "UIWindow",
        ]
        names = names.filter { name in
            return whitelist.contains { name.hasPrefix($0) } && !blacklist.contains { name.hasPrefix($0) }
        }

        // Dedupe view and controller keys
        let viewControllerKeys = UIViewController.expressionTypes
        let viewKeys = UIView.expressionTypes

        // Get properties
        var result = [String: [String: RuntimeType]]()
        for name in names {
            var props: [String: RuntimeType]
            let cls: AnyClass? = NSClassFromString(name)
            switch cls {
            case let viewClass as UIView.Type:
                props = viewClass.expressionTypes
                for (key, type) in viewKeys where props[key] == type {
                    props.removeValue(forKey: key)
                }
            case let controllerClass as UIViewController.Type:
                props = controllerClass.expressionTypes
                for (key, type) in viewControllerKeys where props[key] == type {
                    props.removeValue(forKey: key)
                }
                for (key, type) in viewKeys where props[key] == type {
                    props.removeValue(forKey: key)
                }
            default:
                props = [:]
            }
            result[name] = props
        }
        return result
    }

    func testBuildLayoutToolSymbols() {
        if #available(iOS 11.0, *) {} else {
            XCTFail("Must be run with latest iOS SDK to ensure all symbols are supported")
            return
        }

        // Build output
        var output = ""
        let properties = getProperties()
        for name in properties.keys.sorted() {
            let props = properties[name]!
            output += "    symbols[\"\(name)\"] = ["
            if props.isEmpty {
                output += ":]\n"
            } else {
                output += "\n"
                for prop in props.keys.sorted() {
                    let type = props[prop]!
                    if case .unavailable = type.availability {
                        continue
                    }
                    output += "        \"\(prop)\": \"\(type)\",\n"
                }
                output += "    ]\n"
            }
        }

        output = "//  Copyright © 2017 Schibsted. All rights reserved.\n\n" +
            "import Foundation\n\n" +
            "// NOTE: This is a machine-generated file. Run the UIKitSymbols scheme to regenerate\n\n" +
            "let UIKitSymbols: [String: [String: String]] = {\n" +
            "    var symbols = [String: [String: String]]()\n" + output +
            "    return symbols\n" +
            "}()"

        // Write output
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LayoutTool/Symbols.swift")

        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("\(url) does not exist")
            return
        }

        XCTAssertNoThrow(try output.write(to: url, atomically: true, encoding: .utf8))
    }

    func testBuildSublimeCompletions() {
        if #available(iOS 11.0, *) {} else {
            XCTFail("Must be run with latest iOS SDK to ensure all symbols are supported")
            return
        }

        // Build output
        var rows = [String]()
        let properties = getProperties()
        for name in properties.keys.sorted() {
            let props = properties[name]!
            rows.append("{ \"trigger\": \"\(name)\", \"contents\": \"\(name) $0/>\" }")
            for prop in props.keys.sorted() {
                let type = props[prop]!
                if case .unavailable = type.availability {
                    continue
                }
                let row = "{ \"trigger\": \"\(prop)\t\(type)\", \"contents\": \"\(prop)=\\\"$0\\\"\" }"
                if !rows.contains(row) {
                    rows.append(row)
                }
            }
        }

        let output = "{\n" +
            "    \"scope\": \"text.xml\",\n" +
            "    \"completions\": [\n        " + rows.joined(separator: ",\n        ") + "\n" +
            "    ]\n" +
            "}\n"

        // Write output
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("layout.sublime-completions")

        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("\(url) does not exist")
            return
        }

        XCTAssertNoThrow(try output.write(to: url, atomically: true, encoding: .utf8))
    }
}
