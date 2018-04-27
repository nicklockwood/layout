//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Layout

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        LayoutNode.useLegacyLayoutMode = false

        window = UIWindow()
        window?.rootViewController = ExamplesViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
