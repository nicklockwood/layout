//  Copyright © 2017 Schibsted. All rights reserved.

import QuartzCore

private var _cachedExpressionTypes = [Int: [String: RuntimeType]]()

extension CALayer {
    /// Expression names and types
    @objc class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        types["contents"] = .cgImage
        for key in [
            "borderWidth",
            "contentsScale",
            "cornerRadius",
            "shadowRadius",
            "rasterizationScale",
            "zPosition",
        ] {
            types[key] = .cgFloat
        }
        types["contentsGravity"] = RuntimeType([
            "center",
            "top",
            "bottom",
            "left",
            "right",
            "topLeft",
            "topRight",
            "bottomLeft",
            "bottomRight",
            "resize",
            "resizeAspect",
            "resizeAspectFill",
        ] as Set<String>)
        types["edgeAntialiasingMask"] = .caEdgeAntialiasingMask
        types["fillMode"] = RuntimeType([
            "backwards",
            "forwards",
            "both",
            "removed",
        ] as Set<String>)
        types["minificationFilter"] = RuntimeType([
            "nearest",
            "linear",
        ] as Set<String>)
        types["magnificationFilter"] = RuntimeType([
            "nearest",
            "linear",
        ] as Set<String>)
        types["maskedCorners"] = .caCornerMask
        // Explicitly disabled properties
        for name in [
            "bounds",
            "frame",
        ] {
            types[name] = .unavailable("Use top/left/width/height instead")
            let name = "\(name)."
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable("Use top/left/width/height instead")
            }
        }
        for name in [
            "needsDisplayInRect",
        ] {
            types[name] = .unavailable()
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable()
            }
        }
        for name in [
            "position",
        ] {
            types[name] = .unavailable("Use center.x or center.y instead")
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable("Use center.x or center.y instead")
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
                "contentsSwizzle",
                "continuousCorners",
                "cornerContentsCenter",
                "cornerContentsMaskEdges",
                "disableUpdateMask",
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
