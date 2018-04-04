//  Copyright © 2017 Schibsted. All rights reserved.

// Expressions that affect layout
// These are common to every Layout node
// These are all of type CGFloat, apart from `center` which is a CGPoint
let layoutSymbols: Set<String> = [
    "left", "right", "leading", "trailing",
    "width", "top", "bottom", "height", "center",
    "center.x", "center.y", "firstBaseline", "lastBaseline",
]
