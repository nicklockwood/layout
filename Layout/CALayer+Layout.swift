//  Copyright © 2017 Schibsted. All rights reserved.

import QuartzCore

private var _cachedExpressionTypes = [Int: [String: RuntimeType]]()

extension CALayer {

    /// Expression names and types
    @objc class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        types["contents"] = RuntimeType(CGImage.self)
        for key in [
            "borderWidth",
            "contentsScale",
            "cornerRadius",
            "shadowRadius",
            "rasterizationScale",
            "zPosition",
        ] {
            types[key] = RuntimeType(CGFloat.self)
        }
        types["contentsGravity"] = RuntimeType(String.self, [
            "center": "center",
            "top": "top",
            "bottom": "bottom",
            "left": "left",
            "right": "right",
            "topLeft": "topLeft",
            "topRight": "topRight",
            "bottomLeft": "bottomLeft",
            "bottomRight": "bottomRight",
            "resize": "resize",
            "resizeAspect": "resizeAspect",
            "resizeAspectFill": "resizeAspectFill",
        ] as [String: String])
        types["fillMode"] = RuntimeType(String.self, [
            "backwards": "backwards",
            "forwards": "forwards",
            "both": "both",
            "removed": "removed",
        ] as [String: String])
        types["minificationFilter"] = RuntimeType(String.self, [
            "nearest": "nearest",
            "linear": "linear",
        ] as [String: String])
        types["magnificationFilter"] = RuntimeType(String.self, [
            "nearest": "nearest",
            "linear": "linear",
        ] as [String: String])

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
        ] {
            types[name] = .unavailable()
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable()
            }
        }

        #if arch(i386) || arch(x86_64)
            // Private properties
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
                "momentOfInertia",
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
        #endif
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
