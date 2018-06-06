//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Layout

#if !swift(>=4.2)

    extension UIApplication {
        typealias LaunchOptionsKey = UIApplicationLaunchOptionsKey
    }

#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LayoutNode.useLegacyLayoutMode = false

        window = UIWindow()
        window?.rootViewController = ExamplesViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
