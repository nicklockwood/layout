//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// The current LayoutTool version
let version = "0.4"

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
    print("help")
    print(" - prints this help page")
    print("")
    print("version")
    print(" - prints the currently installed LayoutTool version")
    print("")
    print("format <files>")
    print(" - formats all xml files found at the specified path(s)")
    print("")
    print("list <files>")
    print(" - lists all xml files found at the specified path(s)")
    print("")
    print("rename <files> <old> <new>")
    print(" - renames all occurrences of symbol <old> to <new> in <files>")
    print("")
}

enum ExitResult: Int32 {
    case success = 0
    case error = 1
}

func processArguments(_ args: [String]) -> ExitResult {
    guard args.count > 1 else {
        print("LayoutTool expects at least one argument".inRed, to: &stderr)
        return .error
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
            return .error
        }
        let errors = format(paths)
        for error in errors {
            print("\(error)".inRed, to: &stderr)
        }
        if !errors.isEmpty {
            return .error
        }
    case "list":
        let paths = Array(args.dropFirst(2))
        if paths.isEmpty {
            print("list command expects one or more file paths to search".inRed, to: &stderr)
            return .error
        }
        let errors = list(paths)
        for error in errors {
            print("\(error)".inRed, to: &stderr)
        }
        if !errors.isEmpty {
            return .error
        }
    case "rename":
        var paths = Array(args.dropFirst(2))
        guard let new = paths.popLast(), let old = paths.popLast(), !new.contains("/"), !old.contains("/") else {
            print("rename command expects a symbol name and a replacement".inRed, to: &stderr)
            return .error
        }
        if paths.isEmpty {
            print("rename command expects one or more file paths to search".inRed, to: &stderr)
            return .error
        }
        let errors = rename(old, to: new, in: paths)
        for error in errors {
            print("\(error)".inRed, to: &stderr)
        }
        if !errors.isEmpty {
            return .error
        }
    case let arg:
        print("`\(arg)` is not a valid command".inRed, to: &stderr)
        return .error
    }
    return .success
}

// Pass in arguments and exit
let result = processArguments(CommandLine.arguments)
exit(result.rawValue)
