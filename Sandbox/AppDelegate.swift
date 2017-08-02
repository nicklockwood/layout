//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow()

        let editController = EditViewController()
        window?.rootViewController = UINavigationController(rootViewController: editController)
        editController.showPreview(animated: false)

        window?.makeKeyAndVisible()
        return true
    }
}

