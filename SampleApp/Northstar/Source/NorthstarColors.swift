//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Layout

extension UIColor {

    // Northstar colors

    public static var northstarPrimary: UIColor { return color(#function) }
    public static var northstarSecondary: UIColor { return color(#function) }
    public static var northstarValidate: UIColor { return color(#function) }
    public static var northstarWarning: UIColor { return color(#function) }
    public static var northstarError: UIColor { return color(#function) }
    public static var northstarDark: UIColor { return color(#function) }
    public static var northstarSoft: UIColor { return color(#function) }
    public static var northstarPrimaryText: UIColor { return color(#function) }
    public static var northstarSecondaryText: UIColor { return color(#function) }
    public static var northstarTertiaryText: UIColor { return color(#function) }
    public static var northstarPrimaryButtonText: UIColor { return color(#function) }
    public static var northstarSecondaryButtonText: UIColor { return color(#function) }
    public static var northstarDim: UIColor { return black.withAlphaComponent(0.5) }

    // Deprecated colors

    public static var rocketPrimary: UIColor { return color(#function) }
    public static var rocketSecondary: UIColor { return color(#function) }
    public static var rocketPrimaryDark: UIColor { return color(#function) }
    public static var rocketPrimaryLight: UIColor { return color(#function) }
    public static var rocketBackground: UIColor { return color(#function) }
    public static var rocketTextMain: UIColor { return color(#function) }
    public static var rocketTextSub: UIColor { return color(#function) }
    public static var rocketTextLabel: UIColor { return color(#function) }
    public static var rocketTextError: UIColor { return color(#function) }
    public static var rocketBtnInactive1: UIColor { return color(#function) }
    public static var rocketBtnInactive2: UIColor { return color(#function) }
    public static var rocketErrorBanner: UIColor { return color(#function) }
    public static var rocketSuccessBanner: UIColor { return color(#function) }
    public static var rocketMagic: UIColor { return color(#function) }
    public static var rocketPriceBackground: UIColor { return color(#function) }
    public static var rocketActionPlusButton: UIColor { return color(#function) }
    public static var rocketActionPlusCrossButton: UIColor { return color(#function) }
    public static var rocketCategories: UIColor { return color(#function) }

    private static var colors: [String: String] = [
        "rocketPrimary": "#75B1D5",
        "rocketSecondary": "#FFE889",
        "rocketPrimaryDark": "#679FC3",
        "rocketPrimaryLight": "#9EC8E1",
        "rocketBackground": "#F7F7F7",
        "rocketTextMain": "#1D1D26",
        "rocketTextSub": "#77777D",
        "rocketTextLabel": "#D2D2D4",
        "rocketTextError": "#E94B35",
        "rocketBtnInactive1": "#CCCCCC",
        "rocketBtnInactive2": "#EDEDED",
        "rocketErrorBanner": "#E35B5B",
        "rocketSuccessBanner": "#38C69A",
        "rocketMagic": "#27DD95",
        "rocketPriceBackground": "#75B1D5",
        "rocketActionPlusButton": "#FFE889",
        "rocketActionPlusCrossButton": "#1D1D26",
        "rocketCategories": "#9EC8E1",
        "northstarPrimary": "#75B1D5",
        "northstarSecondary": "#FFE889",
        "northstarValidate": "#5D981C",
        "northstarWarning": "#D58706",
        "northstarError": "#D13649",
        "northstarDark": "#111111",
        "northstarSoft": "#666666",
        "northstarPrimaryText": "#111111",
        "northstarSecondaryText": "#666666",
        "northstarTertiaryText": "#AFAFAF",
        "northstarPrimaryButtonText": "#FCFCFC",
        "northstarSecondaryButtonText": "#111111"
    ]

    private class func color(_ name: String) -> UIColor {
        let name = name.trimmingCharacters(in: .punctuationCharacters)
        guard let color = colors[name] else {
            preconditionFailure("Color '\(name)' not found")
        }
        return UIColor(hexString: color)!
    }
}
