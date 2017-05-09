//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public extension NorthstarLoadable where Self: UIView {

    public static func fromResource() -> Self {
        if let objects = bundle.loadNibNamed(className, owner: self, options: nil) {
            for object in objects {
                if let object = object as? Self {
                    return object
                }
            }
        }
        preconditionFailure("Could not load \(className) from Northstar bundle")
    }

    private func loadContentView() -> UIView {
        let cls = type(of: self)
        if let objects = cls.bundle.loadNibNamed(cls.className, owner: self, options: nil) {
            for object in objects {
                if let object = object as? UIView {
                    return object
                }
            }
        }
        preconditionFailure("No view found in \(cls.className).nib")
    }

    @discardableResult
    public func loadContentsFromResource() -> UIView {
        let view = loadContentView()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)

        if frame.size == .zero {
            frame.size = view.frame.size
            topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
            bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        } else {
            view.frame = bounds
            view.topAnchor.constraint(equalTo: topAnchor).isActive = true
            view.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
            view.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        }

        return view
    }
}
