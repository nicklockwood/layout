//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public extension NorthstarLoadable where Self: UIViewController {

    public static func fromResource() -> Self {
        let storyboard = UIStoryboard(name: className, bundle: bundle)
        if let viewController = storyboard.instantiateViewController(withIdentifier: className) as? Self {
            return viewController
        }
        preconditionFailure("Could not load \(className) from Northstar bundle")
    }
}
