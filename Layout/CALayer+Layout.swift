//  Copyright © 2017 Schibsted. All rights reserved.

import QuartzCore

private var _cachedExpressionTypes = [Int: [String: RuntimeType]]()

extension CALayer {

    /// Expression names and types
    @objc class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        types["contents"] = RuntimeType(CGImage.self)
        // Explicitly disabled properties
        for name in [
            "bounds",
            "frame",
            "position",
        ] {
            types[name] = .unavailable("Use top/left/width/height expressions instead")
            let name = "\(name)."
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable("Use top/left/width/height expressions instead")
            }
        }
        for name in [
            "anchorPoint",
            "needsDisplayInRect",
            "sublayers",
        ] {
            types[name] = .unavailable()
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable()
            }
        }
        for name in [
            "acceleratesDrawing",
            "allowsContentsRectCornerMasking",
            "allowsDisplayCompositing",
            "allowsGroupBlending",
            "allowsHitTesting",
            "backgroundColorPhase",
            "behaviors",
            "canDrawConcurrently",
            "clearsContext",
            "coefficientOfRestitution",
            "contentsContainsSubtitles",
            "contentsDither",
            "contentsMultiplyByColor",
            "contentsOpaque",
            "contentsScaling",
            "continuousCorners",
            "cornerContentsCenter",
            "cornerContentsMaskEdges",
            "doubleBounds",
            "doublePosition",
            "flipsHorizontalAxis",
            "hitTestsAsOpaque",
            "inheritsTiming",
            "invertsShadow",
            "isFlipped",
            "isFrozen",
            "literalContentsCenter",
            "mass",
            "meshTransform",
            "momentOfIntertia",
            "motionBlurAmount",
            "needsLayoutOnGeometryChange",
            "perspectiveDistance",
            "preloadsCache",
            "presentationModifiers",
            "rasterizationPrefersDisplayCompositing",
            "sizeRequisition",
            "sortsSublayers",
            "stateTransitions",
            "states",
            "velocityStretch",
            "wantsExtendedDynamicRangeContent",
        ] {
            types[name] = nil
            for key in types.keys where key.hasPrefix(name) {
                types[key] = nil
            }
        }
        return types
    }

    class var cachedExpressionTypes: [String: RuntimeType] {
        if let types = _cachedExpressionTypes[self.hash()] {
            return types
        }
        let types = expressionTypes
        _cachedExpressionTypes[self.hash()] = types
        return types
    }
}
