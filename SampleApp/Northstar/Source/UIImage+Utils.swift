//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public extension UIImage {
    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 8, height: 8)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(rect.size)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
