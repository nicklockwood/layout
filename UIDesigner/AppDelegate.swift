//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow()

        let splitViewController = UISplitViewController()
        let navigationController = UINavigationController()
        navigationController.viewControllers = [TreeViewController()]
        splitViewController.viewControllers = [navigationController, DesignViewController()]
        splitViewController.delegate = self

        // Hide the tree view for now, as it needs some improvements
        splitViewController.preferredDisplayMode = .primaryHidden

        window?.rootViewController = splitViewController
        window?.makeKeyAndVisible()

        return true
    }
}
