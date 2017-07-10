//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// The current LayoutTool version
let version = "0.2"

extension String {
    var inDefault: String { return "\u{001B}[39m\(self)" }
    var inRed: String { return "\u{001B}[31m\(self)\u{001B}[0m" }
    var inGreen: String { return "\u{001B}[32m\(self)\u{001B}[0m" }
    var inYellow: String { return "\u{001B}[33m\(self)\u{001B}[0m" }
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            write(data)
        }
    }
}

private var stderr = FileHandle.standardError

func printHelp() {
    print("")
    print("LayoutTool, version \(version)")
    print("copyright (c) 2017 Schibsted")
    print("")
    print("help             print this help page")
    print("version          print the currently installed LayoutTool version")
    print("format <files>   format all xml files found at the specified path(s)")
    print("list <files>     list all xml files found at the specified path(s)")
    print("")
}

func processArguments(_ args: [String]) {
    guard args.count > 1 else {
        print("LayoutTool expects at least one argument".inRed, to: &stderr)
        return
    }
    switch args[1] {
    case "help":
        printHelp()
    case "version":
        print(version)
    case "format":
        let paths = Array(args.dropFirst(2))
        if paths.isEmpty {
            print("format command expects one or more file paths as input".inRed, to: &stderr)
        }
        for error in format(paths) {
            print("\(error)".inRed, to: &stderr)
        }
    case "list":
        let paths = Array(args.dropFirst(2))
        if paths.isEmpty {
            print("list command expects one or more file paths to search".inRed, to: &stderr)
        }
        for error in list(paths) {
            print("\(error)".inRed, to: &stderr)
        }
    case let arg:
        print("`\(arg)` is not a valid command".inRed, to: &stderr)
        return
    }
}

// Pass in arguments
processArguments(CommandLine.arguments)
