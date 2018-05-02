//  Copyright © 2018 Schibsted. All rights reserved.

public extension Layout {

    /// Clear all Layout caches
    static func clearAllCaches() {
        Expression.clearCache()
        clearParsedExpressionCache()
        clearLayoutExpressionCache()
        clearRuntimeTypeCache()
        clearCachedViewExpressionTypes()
        clearCachedViewControllerExpressionTypes()
        clearCachedLayerExpressionTypes()
        clearLayoutLoaderCache()
    }
}
