//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public extension UIColor {

    public convenience init?(hexString: String) {
        var hexString = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var hexValue = UInt32(0)
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.characters.count == 6,
            Scanner(string: hexString).scanHexInt32(&hexValue) else {
            return nil
        }

        let divisor = CGFloat(255)

        self.init(red: CGFloat((hexValue & 0xFF0000) >> 16) / divisor,
                  green: CGFloat((hexValue & 0x00FF00) >> 8) / divisor,
                  blue: CGFloat(hexValue & 0x0000FF) / divisor,
                  alpha: 1)
    }

    class func imageWithColor(_ color: UIColor) -> UIImage? {
        let rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), false, 0)
        defer {
            UIGraphicsEndImageContext()
        }
        color.setFill()
        UIRectFill(rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
