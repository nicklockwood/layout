//
//  AppDelegate.swift
//  SampleApp
//
//  Created by Nick Lockwood on 22/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow()
        window?.rootViewController = ExamplesViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
