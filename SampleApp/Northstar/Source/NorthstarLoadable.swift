//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

public protocol NorthstarLoadable: class {}

public extension NorthstarLoadable {

    static var className: String {
        return "\(self)".components(separatedBy: ".").last!
    }

    static var bundle: Bundle {
        let podBundle = Bundle(for: self)
        guard let bundleURL = podBundle.url(forResource: "Northstar", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL) else {
                preconditionFailure("Could not locate Northstar resources bundle")
        }
        return bundle
    }
}
