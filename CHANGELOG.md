# Change Log

## [0.3.3](https://github.schibsted.io/Rocket/layout/releases/tag/0.3.3) (2017-06-27)

- Added `LayoutLoading` protocol, for loading arbitrary views or view controllers from XML
- LayoutVC errors are no longer passed up to parent, which fixes a bug with reloading after an error
- Significantly improved property setting performance - at least 2X faster
- Loading of nested XML files is now synchronous, avoiding a flash as subviews are loaded
- Improved default frame behavior, and added unit tests
- Added support for `UITableView`, `UITableViewCell`, and `UITableViewController`
- Added custom initializer support for views/controllers that require extra arguments
- Added support for `layoutMargins` in expressions

## [0.3.2](https://github.schibsted.io/Rocket/layout/releases/tag/0.3.2) (2017-06-20)

- Reloading a nested LayoutViewController now reloads just the current controller, not the parent
- Fixed potential AutoLayout crash

## [0.3.1](https://github.schibsted.io/Rocket/layout/releases/tag/0.3.1) (2017-06-13)

- You can now reference nested state or constants dictionary keys using keypaths in expressions
- Fixed a major performance regression introduced in 0.2.1, which made the UIDesigner unusable
- Added support for setting CGColor and CGImage properties on a CALayer using expressions
- Fixed string formatting when concatenating optional strings
- Improved null-coalescing operator error messaging
- Improved AnyExpression implementation to eliminate arbitrary limits on numeric values

## [0.3.0](https://github.schibsted.io/Rocket/layout/releases/tag/0.3.0) (2017-06-09)

- Implicitly unwrapping a nil value inside a string expression will now throw instead of printing "nil"
- String and image expressions can now safely return nil values, all other expression types will throw
- Added `nil` literal value, for checking if values are nil inside an expression
- Added `??` null-coalescing operator, for proving fallback values for nil inputs in expressions
- All properties now use AnyExpression internally, meaning they can reference arbitrary types 
- Braces are now permitted around any expression type, making the rules less confusing to remember

## [0.2.6](https://github.schibsted.io/Rocket/layout/releases/tag/0.2.6) (2017-06-08)

- Fixed bug where custom enums would be misidentified as the wrong type
- Fixed bug with events being swallowed inside nested view controllers of LayoutViewController

## [0.2.5](https://github.schibsted.io/Rocket/layout/releases/tag/0.2.5) (2017-06-07)

- Fixed bug with locating xml layout files inside a framework bundle
- Fixed Cmd-R shortcut inside LayoutViewController when presented modally

## [0.2.4](https://github.schibsted.io/Rocket/layout/releases/tag/0.2.4) (2017-06-06)

- Added support for directly using localized strings from XML, and live loading of edited strings
- Added support for missing UIScrollView enum properties
- Added convenient solution for merging constants dictionaries
- Further optimized startup and update performance  

## [0.2.3](https://github.schibsted.io/Rocket/layout/releases/tag/0.2.3) (2017-05-29)

- Fixed bug where inherited state incorrectly shadowed local constants
- Expressions that mix math functions with non-numeric types now work as expected
- Improved expression parsing and evaluation performance

## [0.2.2](https://github.schibsted.io/Rocket/layout/releases/tag/0.2.2) (2017-05-19)

- Fixed a critical bug where Bool properties were not working on 32-bit devices
- Improved performance by not recalculating property types in setters
- Added missing UIButton state setters

## [0.2.1](https://github.schibsted.io/Rocket/layout/releases/tag/0.2.1) (2017-05-19)

- Setting state to the same value no longer triggers an update
- Added support for common Core Graphics geometry types such as `CGPoint`/`CGSize`
- Added support for `UIEdgeInsets`-type properties, and affine/3D transforms
- Passing an invalid expression name now throws an exception instead of crashing
- Using an Optional or implicitly unwrapped Optional for state no longer fails
- Improved handling of Optionals and nil values in constants and state variables
- Fixed some bugs where constants or state variable names shadowed view properties

## [0.2.0](https://github.schibsted.io/Rocket/layout/releases/tag/0.2.0) (2017-05-18)

- Improved support for enums - it's no longer necessary to explicitly work with raw values (breaking change)
- Shadowing of inherited constants and state now works in a more intuitive way
- Cyclical references in expressions now correctly throw an error instead of crashing
- You can now use font names containing spaces in font expressions by wrapping them in single or double quotes

## [0.1.1](https://github.schibsted.io/Rocket/layout/releases/tag/0.1.1) (2017-05-16)

- Added support for single- or double-quoted string literals inside expressions
- Fixed reloading of nested xml file references so it correctly finds the source file
- Improved `auto` sizing logic to better handle `intrinsicContentSize` values

## [0.1.0](https://github.schibsted.io/Rocket/layout/releases/tag/0.1.0) (2017-05-15)

- First release
