# Change Log

## [0.6.17](https://github.com/schibsted/layout/releases/tag/0.6.17) (2018-02-23)

- You can now pass custom functions to `LayoutNode` for use in property expressions (see README for details)
- Updated Expression to 0.12.6, which adds support for inline array literals, string subscripting and more (see README for details)
- Updated LayoutTool and Layout Xcode Editor Extension to support new Expression features
- Fixed (almost) all deprecation warnings in Swift 4.1

## [0.6.16](https://github.com/schibsted/layout/releases/tag/0.6.16) (2018-01-29)

- Improved resolution logic when referencing image or color assets in bundles other than the main bundle
- Fixed top/bottom layout guide not updating correctly on iOS 9 and 10
- Fixed some edge cases when parsing expression comments and improved test coverage
- Updated Expression library to version 0.12.0

## [0.6.15](https://github.com/schibsted/layout/releases/tag/0.6.15) (2018-01-19)

- Fixed bug where safe area insets would not be updated correctly in some cases
- Duplicate instances of the same view or view controller in a LayoutNode hierarchy will now throw an error
- Duplicate outlet names in a LayoutNode hierarchy will now throw an error

## [0.6.14](https://github.com/schibsted/layout/releases/tag/0.6.14) (2018-01-11)

- Fixed longstanding bug where reloading failed to remove the old layout views/controllers from the hierarchy
- It is now safe to create LayoutNode instance on a background thread (though most methods/properties must be accessed from main thread)
- Layout will no longer directly set the `UIViewController` view (introduced in 0.6.11) as this caused issues with reloading
- You can now create LayoutNodes using view/controller classes instead of instances

## [0.6.13](https://github.com/schibsted/layout/releases/tag/0.6.13) (2018-01-10)

- Fixed spurious error when trying to use `center.x` or `center.y` inside an expression
- Fixed a bug where positioning views relative to their parent size would not work if parent was auto-sized
- Added warnings view to LayoutConsole. Warnings appear as a dimissable bar at the bottom of the screen
- Fixed intermittent issue where Layout would get stuck in a loading loop after reloading
- Added a mechanism for marking properties as deprecated

## [0.6.12](https://github.com/schibsted/layout/releases/tag/0.6.12) (2018-01-08)

- Fixed safeAreaInsets regression
- Fixed intermittent bug with UITabBar layout in landscape orientation

## [0.6.11](https://github.com/schibsted/layout/releases/tag/0.6.11) (2018-01-05)

- Deprecated `LayoutViewController`. You can now get all the same functionality by using the `LayoutLoading` protocol
- When loading a layout into a `UIViewController`, Layout will set the view directly when possible, instead of adding a subview
- Fixed infinite loading loop when attempting to load a layout whose root node is the same type as its owner
- Added a new `LayoutDelegate` protocol, inherited by `LayoutLoading`
- Added workaround for nil default `backgroundColor` on `UIView`

## [0.6.10](https://github.com/schibsted/layout/releases/tag/0.6.10) (2018-01-04)

- Localized string lookup in expressions no longer requires you to use LayoutViewController
- Fixed a bug where auto-sized views would not collapse if all their children were hidden

## [0.6.9](https://github.com/schibsted/layout/releases/tag/0.6.9) (2018-01-02)

- You can now position views using `center.x` and `center.y` instead of having to calculate the center offset yourself
- Layout now supports `layer.anchorPoint`, and respects its value when positioning using `center.x/y` expressions
- Added support for `firstBaseline` and `lastBaseline` expressions for positioning text-based views
- Referencing parent properties like `top` and `right` now transforms the value to the current node's coordinate space
- Improved property error Red Box suggestions

## [0.6.8](https://github.com/schibsted/layout/releases/tag/0.6.8) (2017-12-20)

- Fixed a regression in UITableView auto-sizing for cells and section headers
- Array literals in expression are now type checked, Layout and will throw an error if the element types don't match
- `RuntimeType(_: String)` is now deprecated - use `RuntimeType.type(named: String)` instead
- Expressions can now reference properties of nested structs or classes inside state objects

## [0.6.7](https://github.com/schibsted/layout/releases/tag/0.6.7) (2017-12-12)

- Fixed a major performance regression introduced in version 0.6.3 (caused by calling `UIView.layoutIfNeeded()`)
- The Red Box debug console is now attached to the main window, so it no longer requires an onscreen `LayoutViewController`
- The Red Box is now disabled by default in production builds. You can enable it programmatically if you want it to be shown
- The Cmd-R reload shortcut now works in any view or controller, not just subclasses of `LayoutViewController`
- Added a more reliable fix for intermittent crashes when reloading due to a race condition in NSAttributedString logic
- It is now possible to specify `contentHuggingPriority` and `contentCompressionResistancePriority` using expressions
- Fixed a test regression in Xcode 9.2 / iOS 11.2 due to a change in `UIStackView` behavior
- Fixed a bug that caused an infinite update loop for certain types of expression error
- The `layoutDidLoad()` delegate method now receives the `LayoutNode` as an argument (the old method signature is deprecated)

## [0.6.6](https://github.com/schibsted/layout/releases/tag/0.6.6) (2017-12-04)

- Improved support for comma-delimited array literals in expressions, and added support for array subscripting using `[]`
- Upgraded Expression library to 0.9.1, which fixes a number of parsing bugs and improves LayoutTool expression formatting
- Removed UIImagePickerController extension, which caused problems with AppStore Review for apps not using the photo library
- LayoutTool format now logs the number of files it has updated

## [0.6.5](https://github.com/schibsted/layout/releases/tag/0.6.5) (2017-11-29)

- Fixed a bug where `accessibilityIdentifier` property was reported as private or unavailable
- LayoutTool `strings` command now finds parameterized strings

## [0.6.4](https://github.com/schibsted/layout/releases/tag/0.6.4) (2017-11-24)

- Added ability to specify format arguments for localized string constants (see README for details)
- Fixed bug where UIAccessibility properties were reported as private or unavailable

## [0.6.3](https://github.com/schibsted/layout/releases/tag/0.6.3) (2017-11-17)

- Fixed UIStackView bug introduced in 0.6.1, and made further improvements
- Fixed some inconsistent behavior when using empty or commented-out expressions

## [0.6.2](https://github.com/schibsted/layout/releases/tag/0.6.2) (2017-11-15)

- Fixed an infinite recursion bug in the `updateFrame()` logic
- Disabled an assertion that sometimes fired incorrectly due to a race condition
- Fixed a bug where children added programmatically might be positioned incorrectly

## [0.6.1](https://github.com/schibsted/layout/releases/tag/0.6.1) (2017-11-14)

- Expressions that reference the `contentOffset` of a containing UIScrollView now update automatically when it changes
- Layout now automatically calls `setNeedsLayout()` on the containing view of the root LayoutNode when its frame changes
- You can now reference a macro defined in the root node of a Layout XML file from an expression on the root node 
- Improved support for views using AutoLayout (i.e. where `translatesAutoresizingMaskIntoConstraints = false`)
- Fixed a spurious circular reference error relating to implicit height expressions
- Unhandled errors that are thrown outside of a `LayoutViewController` now assert instead of failing silently
- Added strings command to LayoutTool for extracting localizable string references
- Reduced setup time for a Layout view hierarchy by ~30%

## [0.6.0](https://github.com/schibsted/layout/releases/tag/0.6.0) (2017-11-09)

- Outlets can now be set using an expression as long the result is constant (see README for details)
- Error messages now include the name of the Layout XML file where the error occured
- Improved error messages, including bug fixes and better suggestions for mistyped property names
- Added `childNode(withID:)` and `children(withID:)` methods to `LayoutNode` for looking up child nodes
- The `layoutNode` property for Layout-managed table and collection view cells is now public
- Better constant analysis, which should improve performance when updating mostly-static views
- Fixed incorrect error message when expression is missing a closing brace
- Dropped support for Swift 3.1 and Xcode 8.3.3 (this was broken in the previous release anyway)
- Fixed string and character-related warnings in Xcode 9.1
- Minor breaking changes to LayoutError API

## [0.5.9](https://github.com/schibsted/layout/releases/tag/0.5.9) (2017-11-02)

- Fixed assertion failure caused by view layout triggering during a Layout update
- Fixed bug where nested XML templates sometimes failed to load correctly on second use
- Improved font name and weight matching, especially when using custom fonts
- Font weight matching will now match the closest available weight instead of requiring and exact match
- Setting the `style` property is now permitted for `UITableViewCell` subclasses
- Improved font expression documentation

## [0.5.8](https://github.com/schibsted/layout/releases/tag/0.5.8) (2017-10-31)

- Fixed layout glitch after live reloading `UIStackView`-based layouts
- Font expressions now support additional weights such as `black` and `ultralight`
- Minor breaking change when creating bold system fonts in font expressions. See README for details
- Unicode characters in attributedString expressions or inline HTML are no longer mangled
- Fixed bug where source file loading errors were sometimes not reported
- Fixed bug where `.layout-ignore` file paths could sometimes be ignored
- Improved AnyExpression implementation and test coverage
- Fixed bug with loading files in paths containing a period

## [0.5.7](https://github.com/schibsted/layout/releases/tag/0.5.7) (2017-10-26)

- Fixed bug where `UIBarButtonItem.image` could not be set using expressions
- Fixed spurious error when using inline HTML containing attributes
- Fixed missing file select options in filename conflict screen
- Added test coverage statistics using Slather and Coveralls
- Fixed a bug with handling of NaN values in expressions
- Fixed spurious warning in Xcode 9

## [0.5.6](https://github.com/schibsted/layout/releases/tag/0.5.6) (2017-10-24)

- Static class properties and enum cases can now be accessed via their namespace inside expressions
- Fixed an issue where errors were sometimes silently swallowed during layout initialization
- Fixed bug where `UIBarButtonItem.title` could not be set using expressions
- Added benchmark app for comparing Layout and AutoLayout performance

## [0.5.5](https://github.com/schibsted/layout/releases/tag/0.5.5) (2017-10-23)

- Fixed nested macro references
- Fixed spurious error when using `grouped` style for table views
- Fixed bugs when using overlapping property expressions such as `contentSize` and `contentSize.width`
- Improved error messages for nonexistent sub-properties of constants
- Added AutoLayout performance tests for comparison purposes
- Child index is now respected when inserting subviews

## [0.5.4](https://github.com/schibsted/layout/releases/tag/0.5.4) (2017-10-16)

- Added macros feature for reusable expressions and sub-expressions. See README for details
- Added node references, allowing expressions to reference arbitrary nodes in the layout hierarchy
- Added the Layout Xcode Extension, making Layout XML formatting available from within Xcode
- Improved support for inline HTML in templates, including support for inline HTML inside webviews
- Fixed some bugs in the LayoutTool format function

## [0.5.3](https://github.com/schibsted/layout/releases/tag/0.5.3) (2017-10-10)

- Added support for OptionSet properties
- Added basic support for array literals in expressions
- `UIControl` actions can now bind to any parent that implements the method, not just the Layout owner
- Added correct type information for several built-in enum and OptionSet properties
- Enhanced support for various standard controls including `UISwitch` and `UISlider`
- Fixed crash when a parameter expression references a constant or state variable of the same name

## [0.5.2](https://github.com/schibsted/layout/releases/tag/0.5.2) (2017-10-04)

- Error messages for unknown properties and enum values now display suggestions for what you might have meant
- Added enhanced support for several more standard controls, including UIActivityIndicatorView, UIWebView and WKWebView
- Errors that occur during view creation are now displayed with a specific message instead of a generic one
- Errors during UICollectionView creation no longer crash the application
- Commented out expressions no longer produce an error if the expression name is not recognized
- Fixed the tap-to-reload functionality in the Red Box error overlay
- Force reloading using Cmd-Option-R now works immediately instead of requiring an app restart to take effect
- Fixed the UIDesigner app, which was previously broken on Xcode 9
- Fixed a bug where the Layout XML parser sometimes ignored significant whitespace inside inline HTML
- Fixed issue where view sometimes failed to update correctly due to a bug in update suppression logic

## [0.5.1](https://github.com/schibsted/layout/releases/tag/0.5.1) (2017-10-02)

- Fixed a retain cycle inside LayoutNode when referencing read-only view properties inside an expression
- Having expressions for a property and one or more sub-properties (e.g. `contentInset` and `contentInset.left`) now works correctly

## [0.5.0](https://github.com/schibsted/layout/releases/tag/0.5.0) (2017-09-28)

- Added `defaultExpressions` property for custom views (see README for details)
- Percentages in `contentSize` expressions now refer to `self.width` instead of `parent.width`
- Fixed bug that caused views to fail to resize correctly when using default width/height
- Named Image and color asset expressions can now use bundle name instead of identifier
- Improved autocomplete behavior for Sublime Text
- Failing to specify a value for a custom parameter no longer causes a hard crash
- Fixed bug that caused typecheck for struct types to always fail
- Removed the `readOnly` availability mode for `RuntimeType` properties
- A width of `100%` now resolves to zero if the view has no parent, instead of the current size
- Added support for all `UIScrollView.contentInsetAdjustmentBehavior` modes
- Removed `LayoutNode.contentSize` property
- Removed deprecated `state` property

## [0.4.26](https://github.com/schibsted/layout/releases/tag/0.4.26) (2017-09-25)

- Errors thrown during expression parsing phase no longer fail silently
- Fixed spurious error thrown when initializing `UITabBar`
- Improved error reporting for views conforming to `LayoutLoading` protocol
- Fixed crash in Collection example when running on iOS 10
- Fixed infinite loop in `LayoutLoading` protocol error handler
- Setting and getting `directionalLayoutMargins` now works on iOS 9 and above
- Getting `effectiveUserInterfaceLayoutDirection` now works on iOS 9 and above
- Reduced Layout framework compile time by a couple of seconds
- Updated custom component docs

## [0.4.25](https://github.com/schibsted/layout/releases/tag/0.4.25) (2017-09-22)

- Fixed regression in auto-sizing of AutoLayout-based components
- Commenting-out string-based expressions now works more intuitively (see README for details)
- Commenting-out `outlet`, `xml` or `template` attributes now works as you would expect
- Width and height of `UIImageView` are now set to `auto` by default

## [0.4.24](https://github.com/schibsted/layout/releases/tag/0.4.24) (2017-09-20)

- Color expressions now support named color assets in iOS 11
- It is no longer necessary to manually call `update()` after resizing a view programmatically
- Fixed `UIScrollView.contentInsetAdjustmentBehavior` error on iOS 11 when building with iOS 10 SDK
- Added caching for color literals, improving performance for commonly-used colors
- Fixed bug where Layout sometimes failed to locate source XML file when using template composition
- Fixed landscape layout for `UITabBarController` on the iPhone X
- Fixed a bug where `UICollectionView` cells failed to resize themselves after reuse
- Added support for `UICollectionView.reorderingCadence` property

## [0.4.23](https://github.com/schibsted/layout/releases/tag/0.4.23) (2017-09-19)

- Added full, backwards-compatible support for safe areas on iOS 11 (see README for details)
- Percentage sizes now take content insets into account when used inside a scroll view
- Added support for new iOS 11 text input properties
- Improved messaging for XML parsing errors
- Fixed a bug when using parameters with external XML references
- Removed private view properties from the Sublime Text autocomplete suggestions

## [0.4.22](https://github.com/schibsted/layout/releases/tag/0.4.22) (2017-09-10)

- Added Layout XML file autocompletion support for the Sublime Text editor (see README for details)
- Fixed a regression introduced in version 0.4.21 that caused constant values to be re-evaluated on each update 
- View and view controller properties whose value has not changed are no longer re-applied on each update
- Fixed a bug where constant expressions containing `true`, `false` or `nil` were re-evaluated on each update
- Fixed UIStackView auto sizing, which was broken in version 0.4.18
- Clarified documentation for creating custom components
- Improved LayoutTool formatting of expressions

## [0.4.21](https://github.com/schibsted/layout/releases/tag/0.4.21) (2017-09-06)

- Fixed some race conditions in the expression setup process that sometimes resulted in spurious errors
- Fixed a bug where certain readonly properties would incorrectly be marked as settable
- The `UILabel.textAlignment` property is now respected when using an attributedString expression
- Paragraph spacing after `<p>` tags in HTML is now zero. Use `<br/>` to insert a blank line between paragraphs
- Added support for `UILabel.lineBreakMode` property

## [0.4.20](https://github.com/schibsted/layout/releases/tag/0.4.20) (2017-09-05)

- Fixed a change in the `LayoutNode.bind()` implementation that cuased a regression in one of our projects

## [0.4.19](https://github.com/schibsted/layout/releases/tag/0.4.19) (2017-09-05)

- Layout now compiles without modification in Xcode 9 using Swift 3.2 or 4.0
- Fixed a bug with disappearing UIAlertController buttons in iOS 9 (introduced in 0.4.14)
- Improved scrolling performance for auto-sized UITableView cells
- Improved UITableView auto height calculation when using multi-line labels
- UITableView section headers and footers no longer vanish after calling `reloadData` 
- Fixed some bugs in parsing of keyPaths in expressions
- Improved expression parsing performance in Swift 3.2 and above

## [0.4.18](https://github.com/schibsted/layout/releases/tag/0.4.18) (2017-09-01)

- Improved support for `UISearchBar`, `UISegmentedControl` and `UIStepper`
- Added customization options for `UINavigationController`'s navigation bar and toolbar
- Added customization options for `UITabBarController`'s tab bar
- Improved API for handling view constructor arguments and made it public
- Improved documentation for view and view controller integration
- Fixed potential array bounds crash when adding views to a view controller
- Added support for class property expressions

## [0.4.17](https://github.com/schibsted/layout/releases/tag/0.4.17) (2017-08-28)

- You can now use `//` comments inside layout expressions
- Empty expressions are now permitted (they are treated the same as omitting the expression)
- Table cell `auto` height is now calculated correctly for cells using multiline `textLabel`
- The `state` property is now deprecated. Use `setState()` instead
- You can now call animated variants of property setters using `setState(_:animated:)`
- Default width is now capped at 100% of the parent width for views such as labels
- Layout now correctly handles custom classes when app name contains spaces or punctuation
- Throwing an error inside `createView()` for custom view subclasses no longer crashes

## [0.4.16](https://github.com/schibsted/layout/releases/tag/0.4.16) (2017-08-25)

- Fix for spurious "property unavailable" errors when using `UITableView`, `UICollectionView` or `UIStackView`
- Added `UIStackView` documentation to README

## [0.4.15](https://github.com/schibsted/layout/releases/tag/0.4.15) (2017-08-22)

- Reverted a change to constant evaluation order in 0.4.14 that caused a regression in one of our projects
- Added CONTRIBUTING.md

## [0.4.14](https://github.com/schibsted/layout/releases/tag/0.4.14) (2017-08-19)

- Cells can now access constants and state defined in their containing `UITableView` or `UICollectionView`
- `UITableView` and `UICollectionView` now support `auto` correctly inside width and height expressions
- Fixed a bug where errors in `UITableView` and `UICollectionView` cells were not reported
- Named color constants defined as static properties of `UIColor` can now be used in color expressions
- Added `.layout-ignore` file feature for excluding directories from XML-file search

## [0.4.13](https://github.com/schibsted/layout/releases/tag/0.4.13) (2017-08-17)

- Added support for custom parameters for XML templates
- Fixed a bug where `UITableView` section headers were displayed as gray bar when not specified
- `UIControl` actions and outlets now work correctly inside `UITableView` and `UICollectionView` cells
- Fixed bug that prevented views from other modules from being used inside `UITableViewCell` templates
- Improved error messaging, particularly for view properties that unavailable in Layout
- LayoutTool format now performs additional validation of expressions
- Fixed XML parsing performance regression
- Fixed bug where LayoutTool errors were returning a generic message instead of the actual error
- Improved source file lookup performance by ignoring hidden directories (such as .git)

## [0.4.12](https://github.com/schibsted/layout/releases/tag/0.4.12) (2017-08-14)

- Fixed scroll performance when using a UIScrollView as the root node in a Layout hierarchy
- Added support for UITableViewController and UICollectionViewController

## [0.4.11](https://github.com/schibsted/layout/releases/tag/0.4.11) (2017-08-14)

- Non-ascii characters such as emoji are now encoded and displayed correctly when using inline HTML
- LayoutTool rename command can now rename view or controller classes, as well as expression symbols
- Improved LayoutTool error reporting - error messages now include the file in which the error ocurred
- LayoutTool errors are now displayed in Xcode when running LayoutTool as a build phase script
- LayoutTool errors will now fail the build when running LayoutTool as a build phase script

## [0.4.10](https://github.com/schibsted/layout/releases/tag/0.4.10) (2017-08-11)

- Fixed bug that caused file conflicts to be presented as Red Box error overlay instead of the file selection overlay

## [0.4.9](https://github.com/schibsted/layout/releases/tag/0.4.9) (2017-08-10)

- Fixed assertion failure when repeatedly pressing Cmd-R in the simulator
- Fixed bug when creating subclasses of `UITableView`, `UITableViewCell`, `UITableViewController` or `UICollectionView`
- Added support for manipulating `CGAffineTransform` and `CATransform3D` properties using expressions
- Fixed some cases where `value(forSymbol:)` returned nil instead of throwing an error for invalid properties 
- Fixed a bug where `UICollectionView.collectionViewLayout.itemSize` was ignored by default
- Assigning values to properties of a nil object now fails silently instead of throwing an error

## [0.4.8](https://github.com/schibsted/layout/releases/tag/0.4.8) (2017-08-09)

- Added support for the `UIScrollView.contentInsetAdjustmentBehavior` property introduced in iOS 11
- Property accessor now throws an error for non-existent properties instead of returning nil
- Fixed compiler errors in Xcode 9b5

## [0.4.7](https://github.com/schibsted/layout/releases/tag/0.4.7) (2017-08-07)

- First open source release!
- Added support for UICollectionView
- Improved error messaging
- Fixed a bug where AutoLayout support would not work correctly in some cases

## [0.4.6](https://github.com/schibsted/layout/releases/tag/0.4.6) (2017-08-03)

- Added support for UIStackView
- Empty XML files no longer crash Layout
- Changed styling of file disambiguation dialog to avoid confusion with Red Box error dialog
- Added Cmd-alt-R hard reset keyboard shortcut for clearing user file selection
- Unsupported HTML tags now raise an error
- Auto-sizing calculations are now more tolerant of recursive width/height references
- Fixed a circular reference crash in width/height expressions
- Fixed a bug with Red Box error not updating after a reload
- The first two subviews added to a UITableView now become the header and footer respectively
- Fixed an intermittent crash due to reloading in the middle of expression evaluation
- Added Sandbox example app

## [0.4.5](https://github.com/schibsted/layout/releases/tag/0.4.5) (2017-07-28)

- Added basic templating functionality for inheriting common layout attributes and elements
- Nested xml file references now permit the root node of the referenced file to be a subclass
- Datasource and delegate properties can now be set explicitly, or cleared with `nil`
- Errors thrown when evaluating constant expressions are now correctly propagated
- LayoutTool now has a rename function for renaming expression symbols inside xml files
- Better handling of implicitly-unwrapped Optionals in constants or state
- Improved support for selectors and CGRect properties
- Fixed crash in XML parser when handling a malformed layout structure
- Fixed crash in UIDesigner example

## [0.4.4](https://github.com/schibsted/layout/releases/tag/0.4.4) (2017-07-25)

- Selected source paths are now persisted between application launches
- Made the `LayoutNode.bind(to:)` and `LayoutNode.unbind()` methods public
- More helpful errors for empty expressions

## [0.4.3](https://github.com/schibsted/layout/releases/tag/0.4.3) (2017-07-20)

- Added support for `UITableViewHeaderFooterView` layouts for table footers and headers
- You can now define `UITableViewCell` and `UITableViewHeaderFooterView` templates inside the XML for a table
- Enabled setting the properties of a `UITableViewCell.contentView` and `backgroundView` using expressions
- Errors inside `UITableViewCell` layouts now appear in red box instead of being silently discarded
- Added support for percentage-based font sizes
- Improved performance when using nested XML file references by avoiding redundant view creation
- Optimized view property update performance
- Using CGColor and CGImage constants now works correctly
- Added better support for CoreFoundation and CoreGraphics types
- Further improvements to auto-sizing behavior
- Fixed bug where Red Box scrollView delegate could get bound to a custom controller

## [0.4.2](https://github.com/schibsted/layout/releases/tag/0.4.2) (2017-07-17)

- Improved auto-sizing behavior for views using both `intrinsicContentSize` and AutoLayout constraints
- XML Layouts are now cached in memory after first load, removing the overhead of repeated parsing
- Added performance tests for XML loading, and switched performance tests to release mode

## [0.4.1](https://github.com/schibsted/layout/releases/tag/0.4.1) (2017-07-15)

- Added support for dynamic text resizing based on user font size settings
- Improved font expression parsing. Now handles font names containing spaces, even without quotes
- Fixed an occasional glitch where auto-sized table cells would all be positioned at the top of the table

## [0.4.0](https://github.com/schibsted/layout/releases/tag/0.4.0) (2017-07-12)

- Breaking change: `UIScrollView.contentInset` is now taken into account when using `auto` in width/height
- Using `auto` sizing on nodes whose children depend on parent size no longer creates circular reference errors
- Spurious errors are no longer thrown during mounting of the `LayoutNode` due to premature evaluation
- Setup of `LayoutNode` is now deferred until first update, which reduces unnecessary processing
- Layout now automatically detects Obj-C setter methods and allows them to be used as expression properties
- The `LayoutViewController` class now conforms to the `LayoutLoading` protocol
- Fixed a bug introduced in version 0.3.4 that affected AutoLayout-based view sizing
- Added caching for computed properties, which improves update performance
- Fixed live reloading of strings

## [0.3.6](https://github.com/schibsted/layout/releases/tag/0.3.6) (2017-07-10)

- Conflict resolution now ignores xml or strings files inside build directory
- Made conflict resolution urls more readable by removing common path prefixes
- Fixed bug where error red box would not update after the error was fixed
- Improved support for standard Cocoa struct types
- LayoutTool now formats expressions as well as general XML structure
- Internalized the Expression library dependency, to simplify integration with LayoutTool

## [0.3.5](https://github.com/schibsted/layout/releases/tag/0.3.5) (2017-07-05)

- Added conflict resolution for when multiple strings or XML layout files have the same name
- UIControl event bindings are now more reliable, and added error detection for misspellings
- Fixed bug where XML validation errors were not displayed
- Added LayoutTool project and tests
- Restructured project and removed Northstar example

## [0.3.4](https://github.com/schibsted/layout/releases/tag/0.3.4) (2017-06-29)

- Added support for dynamic table cell height based on AutoLayout
- Improved AutoLayout integration and fixed a potential crash
- Improved performance by avoiding double-evaluation of frame properties on each layout
- Fixed a bug where a circular reference could cause a crash in some cases instead of showing a red box

## [0.3.3](https://github.com/schibsted/layout/releases/tag/0.3.3) (2017-06-27)

- Added `LayoutLoading` protocol, for loading arbitrary views or view controllers from XML
- LayoutVC errors are no longer passed up to parent, which fixes a bug with reloading after an error
- Significantly improved property setting performance - at least 2X faster
- Loading of nested XML files is now synchronous, avoiding a flash as subviews are loaded
- Improved default frame behavior, and added unit tests
- Added support for `UITableView`, `UITableViewCell`, and `UITableViewController`
- Added custom initializer support for views/controllers that require extra arguments
- Added support for `layoutMargins` in expressions

## [0.3.2](https://github.com/schibsted/layout/releases/tag/0.3.2) (2017-06-20)

- Reloading a nested LayoutViewController now reloads just the current controller, not the parent
- Fixed potential AutoLayout crash

## [0.3.1](https://github.com/schibsted/layout/releases/tag/0.3.1) (2017-06-13)

- You can now reference nested state or constants dictionary keys using keypaths in expressions
- Fixed a major performance regression introduced in 0.2.1, which made the UIDesigner unusable
- Added support for setting CGColor and CGImage properties on a CALayer using expressions
- Fixed string formatting when concatenating optional strings
- Improved null-coalescing operator error messaging
- Improved AnyExpression implementation to eliminate arbitrary limits on numeric values

## [0.3.0](https://github.com/schibsted/layout/releases/tag/0.3.0) (2017-06-09)

- Implicitly unwrapping a nil value inside a string expression will now throw instead of printing "nil"
- String and image expressions can now safely return nil values, all other expression types will throw
- Added `nil` literal value, for checking if values are nil inside an expression
- Added `??` null-coalescing operator, for proving fallback values for nil inputs in expressions
- All properties now use AnyExpression internally, meaning they can reference arbitrary types 
- Braces are now permitted around any expression type, making the rules less confusing to remember

## [0.2.6](https://github.com/schibsted/layout/releases/tag/0.2.6) (2017-06-08)

- Fixed bug where custom enums would be misidentified as the wrong type
- Fixed bug with events being swallowed inside nested view controllers of LayoutViewController

## [0.2.5](https://github.com/schibsted/layout/releases/tag/0.2.5) (2017-06-07)

- Fixed bug with locating xml layout files inside a framework bundle
- Fixed Cmd-R shortcut inside LayoutViewController when presented modally

## [0.2.4](https://github.com/schibsted/layout/releases/tag/0.2.4) (2017-06-06)

- Added support for directly using localized strings from XML, and live loading of edited strings
- Added support for missing UIScrollView enum properties
- Added convenient solution for merging constants dictionaries
- Further optimized startup and update performance  

## [0.2.3](https://github.com/schibsted/layout/releases/tag/0.2.3) (2017-05-29)

- Fixed bug where inherited state incorrectly shadowed local constants
- Expressions that mix math functions with non-numeric types now work as expected
- Improved expression parsing and evaluation performance

## [0.2.2](https://github.com/schibsted/layout/releases/tag/0.2.2) (2017-05-19)

- Fixed a critical bug where Bool properties were not working on 32-bit devices
- Improved performance by not recalculating property types in setters
- Added missing UIButton state setters

## [0.2.1](https://github.com/schibsted/layout/releases/tag/0.2.1) (2017-05-19)

- Setting state to the same value no longer triggers an update
- Added support for common Core Graphics geometry types such as `CGPoint`/`CGSize`
- Added support for `UIEdgeInsets`-type properties, and affine/3D transforms
- Passing an invalid expression name now throws an exception instead of crashing
- Using an Optional or implicitly unwrapped Optional for state no longer fails
- Improved handling of Optionals and nil values in constants and state variables
- Fixed some bugs where constants or state variable names shadowed view properties

## [0.2.0](https://github.com/schibsted/layout/releases/tag/0.2.0) (2017-05-18)

- Improved support for enums - it's no longer necessary to explicitly work with raw values (breaking change)
- Shadowing of inherited constants and state now works in a more intuitive way
- Cyclical references in expressions now correctly throw an error instead of crashing
- You can now use font names containing spaces in font expressions by wrapping them in single or double quotes

## [0.1.1](https://github.com/schibsted/layout/releases/tag/0.1.1) (2017-05-16)

- Added support for single- or double-quoted string literals inside expressions
- Fixed reloading of nested xml file references so it correctly finds the source file
- Improved `auto` sizing logic to better handle `intrinsicContentSize` values

## [0.1.0](https://github.com/schibsted/layout/releases/tag/0.1.0) (2017-05-15)

- First release
