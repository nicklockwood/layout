[![Travis](https://img.shields.io/travis/schibsted/layout.svg)](https://travis-ci.org/schibsted/layout)
[![Platform](https://img.shields.io/cocoapods/p/Layout.svg?style=flat)](http://cocoadocs.org/docsets/Layout)
[![Swift](https://img.shields.io/badge/swift-3.1-orange.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](https://opensource.org/licenses/MIT)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Layout.svg)](https://img.shields.io/cocoapods/v/Layout.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

# Layout

- [Introduction](#introduction)
    - [What?](#what)
    - [Why?](#why)
    - [How?](#how)
- [Usage](#usage)
    - [Installation](#installation)
    - [Integration](#integration)
    - [Live Reloading](#live-reloading)
    - [Constants](#constants)
    - [State](#state)
    - [Actions](#actions)
    - [Outlets](#outlets)
    - [Delegates](#delegates)
- [Expressions](#expressions)
    - [Layout Properties](#layout-properties)
    - [Geometry](#geometry)
    - [Strings](#strings)
    - [Colors](#colors)
    - [Images](#images)
    - [Fonts](#fonts)
    - [Attributed Strings](#attributed-strings)
    - [Optionals](#optionals)
- [Custom Components](#custom-components)
    - [Namespacing](#namespacing)
    - [Custom Property Types](#custom-property-types)
- [Advanced Topics](#advanced-topics)
    - [Layout-based Components](#layout-based-components)
    - [Manual Integration](#manual-integration)
    - [Table Views](#table-views)
    - [Collection Views](#collection-views)
    - [Composition](#composition)
    - [Templates](#templates)
    - [Parameters](#parameters)
    - [Ignore File](#ignore-file)
- [Example Projects](#example-projects)
    - [SampleApp](#sampleapp)
    - [UIDesigner](#uidesigner)
- [LayoutTool](#layouttool)
    - [Installation](#installation-1)
    - [Formatting](#formatting)
- [FAQ](#faq)

# Introduction

## What?

Layout is a framework for implementing iOS user interfaces using runtime-evaluated expressions for layout and (optionally) XML template files. It is intended as a more-or-less drop-in replacement for Nibs and Storyboards, but offers a number of advantages.

To find out more about why we built Layout, and the problems it addresses, check out [this article](http://bytes.schibsted.com/layout-declarative-ui-framework-ios/).


## Why?

Layout seeks to address a number of issues that make Storyboards unsuitable for large, collaborative projects, including:

* Proprietary, undocumented format
* Poor composability and reusability
* Difficult to apply common style elements and metric values without copy-and-paste
* Hard for humans to read, and consequently hard to resolve merge conflicts
* Limited WYSIWYG capabilities

Layout also includes a replacement for AutoLayout that aims to be:

* Simpler to use for basic layouts
* More intuitive and readable for complex layouts
* More deterministic and simpler to debug
* More performant (at least in theory :-))


## How?

Layout introduces a new node hierarchy for managing views, similar to the "virtual DOM" used by React Native.

Unlike UIViews (which use NSCoding for serialization), this hierarchy can be deserialized from a lightweight, human-readable XML format, and also offers a concise API for programmatically generating view layouts in code when you don't want to use a separate resource file.

View properties are specified using *expressions*, which are simple, pure functions stored as strings and evaluated at runtime. Now, I know what you're thinking - *stringly typed code is horrible!* - but Layout's expressions are strongly-typed, and designed to fail early, with detailed error messages to help you debug.

Layout is designed to work with ordinary UIKit components, not to replace or reinvent them. Layout-based views can be embedded inside Nibs and Storyboards, and Nib and Storyboard-based views can be embedded inside Layout-based views and view controllers, so there is no need to rewrite your entire app if you want to try using Layout.


# Usage

## Installation

Layout is provided as a standalone Swift framework that you can use in your app. It has no dependencies, and is not tied to any particular package management solution.

To install Layout using CocoaPods, add the following to your Podfile:

```ruby
pod 'Layout', '~> 0.4.12'
```

To install use Carthage, add this to your Cartfile:

```
github "schibsted/Layout" ~> 0.4.12
```

## Integration

The primary API exposed by Layout is the `LayoutNode` class. Create a layout node as follows:

```swift
let node = LayoutNode(
    view: UIView(),
    expressions: [
        "width": "100%",
        "height": "100%",
        "backgroundColor": "#fff",
    ],
    children: [
        LayoutNode(
            view: UILabel(),
            expressions: [
                "width": "100%",
                "top": "50% - height / 2",
                "textAlignment": "center",
                "font": "Courier bold 30",
                "text": "Hello World",
            ]
        )
    ]
)
```

This example code creates a centered `UILabel` inside a `UIView` with a white background that will stretch to fill its superview once mounted.

For simple views, creating the layout in code is a convenient solution that avoids the need for an external file. But the real power of the Layout framework comes from the ability to specify layouts using external XML files, because it allows for [live reloading](#live-reloading), which can significantly reduce development time.

The equivalent XML markup for the layout above is:

```xml
<UIView
    width="100%"
    height="100%"
    backgroundColor="#fff">
    <UILabel
        width="100%"
        top="50% - height / 2"
        textAlignment="center"
        font="Courier bold 30"
        text="Hello World"
    />
</UIView>
```

Most built-in iOS views should work when used as a layout XML element. For custom views, see the [Custom Components](#custom-components) section below.

To mount a `LayoutNode` inside a view or view controller, subclass `LayoutViewController` and use one of the following three approaches to load your layout:

```swift
class MyViewController: LayoutViewController {

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Option 1 - create a layout programmatically
        self.layoutNode = LayoutNode( ... )

        // Option 2 - load a layout synchronously from a bundled XML file
        self.loadLayout(named: ... )

        // Option 3 - load a layout asynchronously from an XML file URL
        self.loadLayout(withContentsOfURL: ... )
    }
}
```

Use option 1 for layouts generated in code. Use option 2 for XML layout files located inside the application resource bundle.

Option 3 can be used to load a layout from an arbitrary URL, which can be either a local file or remotely-hosted. This is useful if you need to develop directly on a device, because you can host the layout file on your Mac and then connect to it from the device to allow reloading of changes without recompiling the app. It's also potentially useful in production for hosting layouts in some kind of CMS system.

**Note:** The `loadLayout(withContentsOfURL:)` method offers limited control over caching, etc. so if you intend to host your layout files remotely, it may be better to download the XML to a local cache location first and then load it from there.


## Live Reloading

The `LayoutViewController` provides a number of helpful features to improve your development productivity, most notably the *Red Box* debugger and the *live reloading* feature.

If the Layout framework throws an error during XML parsing, mounting, or updating, the `LayoutViewController` will detect it and display the *Red Box*, which is a full-screen overlay that displays the error message along with a reload button. Pressing reload will reset the layout state and re-load the layout XML file.

When you load an XML layout file in the iOS Simulator, the Layout framework will attempt to find the original source XML file for the layout and load that instead of the static version bundled into the compiled app.

This means that you can go ahead and fix the errors in your XML file, then reload it *without* restarting the simulator, or recompiling the app.

**Note:** If multiple source files match the bundled file name, you will be asked to choose which one to load. See the [Ignore File](#ignore-file) section below if you need to exclude certain files from the search process.

You can reload at any time, even if there was no error, by pressing Cmd-R in the simulator (not in Xcode itself, as that will recompile the app). `LayoutViewController` will detect that key combination and reload the XML, provided that it is the current first responder on screen.

**Note:** This only works for changes you make to your layout XML files, or in your `Localizable.strings` file, not for Swift code changes in your view controller, or other resources such as images.

The live reloading feature, combined with the gracious handling of errors, means that it should be possible to do most of your interface development without needing to recompile the app.


## Constants

Static XML is all very well, but most app content is dynamic. Strings, images, and even layouts themselves need to change at runtime based on user-generated content, the current locale, etc.

`LayoutNode` provides two mechanisms for passing dynamic data, which can then be referenced inside your layout expressions: *constants* and *state*.

Constants - as the name implies - are values that remain constant for the lifetime of the `LayoutNode`. These values don't need to be constant for the lifetime of the *app*, but changing them means re-creating the `LayoutNode` and its associated view hierarchy from scratch. The constants dictionary is passed into the `LayoutNode` initializer, and can be referenced by any expression in that node or any of its children.

A good use for constants would be localized strings, or something like colors or fonts used by the app UI theme. These are things that never (or rarely) change during the lifecycle of the app, so it's acceptable that the view hierarchy must be torn down in order to reset them.

Here is how you would pass some constants to your XML-based layout:

```swift
loadLayout(
    named: "MyLayout.xml",
    constants: [
        "title": NSLocalizedString("homescreen.title", message: ""),
        "titleColor": UIColor.primaryThemeColor,
        "titleFont": UIFont.systemFont(ofSize: 30),
    ]
)
```

And how you might reference them in the XML:

```xml
<UIView ... >
    <UILabel
        width="100%"
        textColor="titleColor"
        font="{titleFont}"
        text="{title}"
    />
</UIView>
```

(You may have noticed that the `title` and `titleFont` constants are surrounded by `{...}` braces, but the `titleColor` constant isn't. This is explained in the [Strings](##strings) and [Fonts](##fonts) subsections below.)

You will probably find that some constants are common to every layout in your application, for example if you have constants representing standard spacing metrics, fonts or colors. It would be annoying to have to repeat these everywhere, but the lack of a convenient way to merge dictionaries in Swift (as of version 3.0) makes it painful to use a static dictionary of common constants as well.

For this reason, the `constants` argument of `LayoutNode`'s initializer is actually variadic, allowing you to pass multiple dictionaries, which will be merged automatically. This makes it much more pleasant to combine a global constants dictionary with a handful of custom values:

```swift
let extraConstants: [String: Any] = ...

loadLayout(
    named: "MyLayout.xml",
    constants: globalConstants, extraConstants, [
        "title": NSLocalizedString("homescreen.title", message: ""),
        "titleColor": UIColor.primaryThemeColor,
        "titleFont": UIFont.systemFont(ofSize: 30),
    ]
)
```

## State

For more dynamic layouts, you may have properties that need to change frequently (perhaps even during an animation), and recreating the entire view hierarchy to change these is neither convenient nor efficient. For these properties, you can use *state*. State works in much the same way as constants, except you can update state after the `LayoutNode` has been initialized:

```swift
loadLayout(
    named: "MyLayout.xml",
    state: [
        "isSelected": false,
    ],
    constants: [
        "title": ...
    ]
)

func setSelected() {
    self.layoutNode?.setState(["isSelected": true])
}
```

Note that you can use both constants and state in the same Layout. If a state variable has the same name as a constant, the state variable takes precedence. As with constants, state values can be passed in at the root node of a hierarchy and accessed by any child node. If children in the hierarchy have their own constant or state properties, these will take priority over values set on their parent(s).

Although state can be updated dynamically, all state properties referenced in the layout must have been given a value before the `LayoutNode` is first mounted/updated. It's generally a good idea to set default values for all state variables when you first initialize the node.

Calling `setState()` on a `LayoutNode` after it has been created will trigger an update. The update causes all expressions in that node and its children to be re-evaluated. In future it may be possible to detect if parent nodes are indirectly affected by the state changes of their children and update them too, but currently that is not implemented.

In the example above, we've used a dictionary to store the state values, but `LayoutNode` supports the use of arbitrary objects for state. A really good idea for layouts with complex state requirements is to use a `struct` to store the state. When you set the state using a `struct` or `class`, Layout uses Swift's introspection features to compare changes and determine if an update is necessary.

Internally the `LayoutNode` still just treats the struct as a dictionary of key/value pairs, but you get to take advantage of compile-time type validation when manipulating your state programmatically in the rest of your program:

```swift
struct LayoutState {
    let isSelected: Bool
}

loadLayout(
    named: "MyLayout.xml",
    state: LayoutState(isSelected: false),
    constants: [
        "title": ...
    ]
)

func setSelected() {
    self.layoutNode?.setState(LayoutState(isSelected: false))
}
```

When using a state dictionary, you do not have to pass every single property each time you set the state. If you are only updating one property, it is fine to pass a dictionary with only that key/value pair. (This is not the case if you are using a struct, but don't worry - this is only a convenience feature, and makes no difference to performance.):

```swift
loadLayout(
  named: "MyLayout.xml",
  state: [
    "value1": 5,
    "value2": false,
  ]
)

func setSelected() {
    self.layoutNode?.setState(["value1": 10]) // value2 retains its previous value
}
```

## Actions

For any non-trivial view you will need to bind actions from controls in your view hierarchy to your view controller, and communicate user actions back to the view.

You can define actions on any `UIControl` subclass using `actionName="methodName"` in your XML, for example:

```xml
<UIButton touchUpInside="wasPressed"/>
```

There is no need to specify a target - the action will be automatically bound to the first matching method encountered in the responder chain. If no matching method is found, Layout will display an error. **Note:** the error will be shown *when the node is mounted*, not deferred until the button is pressed, as it would be for actions bound using Interface Builder.

```swift
func wasPressed() {
    ...
}
```

The actions's method name follows the Objective-C selector syntax conventions, so if you wish to pass the button itself as a sender, use a trailing colon in the method name:

```xml
<UIButton touchUpInside="wasPressed:"/>
```

Then the corresponding method can be implemented as:

```swift
func wasPressed(_ button: UIButton) {
    ...
}
```

Action expressions are treated as strings, and like other string expressions they can contain logic to produce a different value depending on the layout constants or state. This is useful if you wish to toggle the action between different methods, e.g.

```xml
<UIButton touchUpInside="{isSelected ? 'deselect:' : 'select:'}"/>
```

In this case, the button will call either the `select(_:)` or `deselect(_:)` methods, depending on the value of the `isSelected` state variable.


## Outlets

When creating views inside a Nib or Storyboard, you typically create references to individual views by using properties in your view controller marked with the `@IBOutlet` attribute, and Layout can utilize the same system to let you reference individual views in your hierarchy from code.

To create an outlet binding for a layout node, declare a property of the correct type on your `LayoutViewController`, and then reference it using the `outlet` constructor argument for the `LayoutNode`:

```swift
class MyViewController: LayoutViewController {

    var labelNode: LayoutNode? // outlet

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.layoutNode = LayoutNode(
            view: UIView(),
            children: [
                LayoutNode(
                    view: UILabel(),
                    outlet: #keyPath(self.labelNode),
                    expressions: [ ... ]
                )
            ]
        )
    }
}
```

In this example we've bound the `LayoutNode` containing the `UILabel` to the `labelNode` property. A few things to note:

* There's no need to use the `@IBOutlet` attribute for your `outlet` property, but you can do so if you feel it makes the purpose clearer. If you do not use `@IBOutlet`, you may need to use `@objc` to ensure the property is visible to Layout at runtime.
* The type of the `outlet` property can be either `LayoutNode` or a `UIView` subclass that's compatible with the view managed by the node. The syntax is the same in either case - the type will be checked at runtime, and an error will be thrown if it doesn't match up.
* In the example above we have used Swift's `#keyPath` syntax to specify the `outlet` value, for better static validation. This is recommended, but not required.
* The `labelNode` outlet in the example has been marked as Optional. It is common to use Implicty Unwrapped Optionals (IUOs) when defining IBOutlets, and that will work with Layout too, but it will result in a hard crash if you make a mistake in your XML and then try to access the outlet. Using regular Optionals means XML errors can be trapped and fixed without restarting the app.

To specify outlet bindings when using XML templates, use the `outlet` attribute:

```xml
<UIView>
    <UILabel
        outlet="labelNode"
        text="Hello World"
    />
</UIView>
```

In this case we lose the static validation provided by `#keyPath`, but Layout still performs a runtime check and will throw a graceful error in the event of a typo or type mismatch, rather than crashing. Note that although the `outlet` attribute is set in the same way as an expression, it is just a constant string, and cannot contain expression logic.

## Delegates

Another commonly-used feature in iOS is the *delegate* pattern. Layout also supports this, but it does so in an implicit way that may be confusing if you aren't expecting it.

When loading a layout XML file, or a programmatically-created `LayoutNode` hierarchy into a `LayoutViewController`, the views will be scanned for delegate properties and these will be automatically bound to the `LayoutViewController` *if* it conforms to the specified protocol.

So for example, if your layout contains a `UIScrollView`, and your view controller conforms to the `UIScrollViewDelegate` protocol, then the view controller will automatically be attached as the delegate for the view controller:

```swift
class MyViewController: LayoutViewController, UITextFieldDelegate {
    var labelNode: LayoutNode!

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.layoutNode = LayoutNode(
            view: UIView()
            children: [
                LayoutNode(
                    view: UITextField(), // delegate is automatically bound to MyViewController
                    expressions: [ ... ]
                )
            ]
        )
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
```

There are a few caveats to watch out for, however:

* This mechanism currently only works for properties called "delegate" or "dataSource". These are the standard names used by UIKit components, but if you have a custom control that uses a different name for its delegate, it won't work automatically, and you will need to bind it programmatically.

* The binding mechanism relies on Objective-C runtime protocol detection, so it won't work for Swift protocols that aren't `@objc`-compliant.

* If you have multiple views in your layout that all use the same delegate protocol, e.g. several `UIScrollView`s or several `UITextField`s, then they will *all* be bound to the view controller. If you are only interested in receiving events from some views and not others, you can either add logic inside the delegate method to determine which view is calling it, or explicitly disable the `delegate` properties of those views by setting them to `nil`:

```xml
<UITextField delegate="nil"/>
```

You can also set the delegate to a specific object by passing a reference to it as a state variable or constant and then referencing that in your delegate expression:

```swift
self.layoutNode = LayoutNode(
    view: UIView()
    constants: [
        "fieldDelegate": someDelegate
    ],
    children: [
        LayoutNode(
            view: UITextField(),
            expressions: [
                "delegate": "fieldDelegate"
            ]
        )
    ]
)
```

Note that there is currently no safe way to explicitly bind a delegate to the layoutNode's owner class. Attempting to pass `self` as a constant or state variable will result in a retain cycle (which is why owner-binding is handled implicitly instead of explicitly).


# Expressions

The most important feature of the `LayoutNode` class is its built-in support for parsing and evaluating expressions. The implementation of this feature is built on top of the [Expression](https://github.com/nicklockwood/Expression) framework, but Layout adds a number of extensions in order to support arbitrary types and layout-specific logic.

Expressions can be simple, hard-coded values such as "10", or more complex expressions such as "width / 2 + someConstant". The available operators and functions to use in an expression depend on the name and type of the property being expressed, but all expressions support the standard decimal math and boolean operators and functions that you find in most C-family programming languages.

Expressions in a `LayoutNode` can reference constants and state passed in to the node or any of its parents. They can also reference the values of any other expression defined on the node, or any supported property of the view:

```
5 + width / 3
isSelected ? blue : gray
min(width, height)
a >= b ? a : b
pi / 2
```

Additionally, a node can reference properties of its parent node using `parent.someProperty`, or of its immediate sibling nodes using `previous.someProperty` and `next.someProperty`.

## Layout Properties

The set of expressible properties available to a `LayoutNode` depends on the view, but every node supports the following properties at a minimum:

```
top
left
bottom
right
width
height
```

These are numeric values (measured in screen points) that specify the frame for the view. In addition to the standard operators, all of these properties allow values specified in percentages:

```xml
<UIView right="50%"/>
```

Percentage values are relative to the width or height of the parent `LayoutNode` (or the superview, if the node has no parent). The expression above is equivalent to writing:

```xml
<UIView right="parent.width / 2">
```

Additionally, the `width` and `height` properties can make use of a virtual variable called `auto`. The `auto` variable equates to the content width or height of the node, which is determined by a combination of three things:

* The `intrinsicContentSize` property of the native view (if specified)
* Any AutoLayout constraints applied to the view by its (non-Layout-managed) subviews
* The enclosing bounds for all the children of the node.

If a node has no children and no intrinsic size, `auto` is equivalent to `100%`.

Though entirely written in Swift, the Layout library makes heavy use of the Objective-C runtime to automatically generate property bindings for any type of view. The available properties therefore depend on the type of view that is passed into the `LayoutNode` constructor (or the name of the XML node, if you are using XML layouts).

Only types that are visible to the Objective-C runtime can be detected automatically. Fortunately, since UIKit is an Objective-C framework, most view properties work just fine. For ones that don't, it is possible to manually expose these using an extension on the view (this is covered below under [Advanced Topics](#advanced-topics)).

Because it is possible to pass in arbitrary values via constants and state, Layout supports referencing almost any type of value inside an expression, even if there is no way to express it as a literal.

Expressions are strongly-typed, so passing the wrong type of value to a function or operator or returning the wrong type from an expression will result in an error. Where possible, these type checks are performed when the node is first mounted, so that the error is surfaced immediately.

The following types of property are given special treatment in order to make it easier to specify them using an expression string:

## Geometry

Because Layout manages the view frame automatically, direct manipulation of the view's frame, bounds and position via expressions is not permitted - you should use the `top`/`left`/`bottom`/`right`/`width`/`height` expressions instead. However, there are other geometric properties that do not directly affect the frame, and many of these *are* available to be set via expressions, for example:

* contentSize
* contentInset
* layer.transform

These properties are not simple numbers, but structs containing several packed values. So how can you manipulate these with Layout expressions?

Well, firstly, almost any property type can be set using a constant or state variable, even if there is no way to define a literal value for it in an expression. So for example, the following code will set the `layer.transform` even though Layout has no way to specify a literal `CATransform3D` struct in an expression:

```swift
loadLayout(
    named: "MyLayout.xml",
    state: [
        "flipped": true
    ],
    constants: [
        "identityTransform": CATransform3DIdentity,
        "flipTransform": CATransform3DMakeScale(1, 1, -1)
    ]
)
```

```xml
<UIView layer.transform="flipped ? flipTransform : identityTransform"/>
```

For many geometric struct types, such as `CGPoint`, `CGSize`, `CGRect`, `CGAffineTransform` and `UIEdgeInsets`, Layout has built-in support for directly referencing the member properties in expressions. To set the top `contentInset` value for a `UIScrollView`, you could use:

```xml
<UIScrollView contentInset.top="topLayoutGuide.length + 10"/>
```

And to explicitly set the `contentSize`, you could use:

```xml
<UIScrollView
    contentSize.width="200%"
    contentSize.height="auto + 20"
/>
```

(Note that `%` and `auto` are permitted inside `contentSize.width` and `contentSize.height`, just as they are for `width` and `height`.)

Layout also supports virtual keyPath properties for manipulating `CATransform3D` (as documented [here](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreAnimation_guide/Key-ValueCodingExtensions/Key-ValueCodingExtensions.html)), and makes equivalent properties available for `CGAffineTransform`. That means you can perform operations like rotating or scaling a view directly in your Layout XML without needing to do any matrix math:

```xml
<UIView transform.rotation="pi / 2"/>

<UIView transform.scale="0.5"/>

<UIView layer.transform.translation.z="500"/>
```

## Strings

It is often necessary to use literal strings inside an expression, and since expressions themselves are typically wrapped in quotes, it would be annoying to have to used nested quotes every time. For this reason, string expressions are treated as literal strings by default, so in this example...

```xml
<UILabel text="title"/>
```

...the `text` property of the label has been given the literal value "title", and not the value of a constant named "title", as you might expect.

To use an expression inside a string property, escape the value using `{ ... }` braces. So to use a constant or variable named `title` instead of the literal value "title", you would write this:

```xml
<UILabel text="{title}"/>
```

You can use arbitrary logic inside the braced expression block, including math and boolean comparisons. The value of the expressions need not be a string, as the result will be *stringified*. You can use multiple expression blocks inside a single string expression, and mix and match expression blocks with literal segments:

```xml
<UILabel text="Hello {name}, you have {n + 1} new messages"/>
```

If you need to use a string literal *inside* an expression block, then you can use single quotes to escape it:

```xml
<UILabel text="Hello {hasName ? name : 'World'}"/>
```

If your app is localized, you will need to use constants instead of literal strings for virtually all of the strings in your template. Localizing all of these strings and passing them as individual constants would be rather tedious, so Layout offers some alternatives:

Constants prefixed with `strings.` are assumed to be localized strings, and will be looked up in the application's `Localizable.strings` file. So for example, if your `Localizable.strings` file contains the following entry:

```
"Signup.NameLabel" = "Name";
```

Then you can reference this directly in your XML as follows, without creating an explicit constant in code:

```xml
<UILabel text="{strings.Signup.NameLabel}"/>
```

It's common practice on iOS to use the English text as the key for localized strings, which may often contain spaces or punctuation, making it invalid as an identifier. In these cases, you can use backticks to escape the key, as follows:

```xml
<UILabel text="{`strings.Some text with spaces and punctuation!`}"/>
```

In addition to reducing boilerplate, strings referenced directly from your XML will also take advantage of [live reloading](#live-reloading), so you can make changes to your `Localizable.strings` file, and they will be picked up when you type Cmd-R in the simulator, with no need to recompile the app.


## Colors

Colors can be specified using CSS-style rgb(a) hex literals. These can be 3, 4, 6 or 8 digits long, and are prefixed with a `#`:

```
#fff // opaque white
#fff7 // 50% transparent white
#ff0000 // opaque red
#ff00007f // 50% transparent red
```

All built-in static UIColor constants are supported as well:

```
white
red
darkGray
etc.
```

You can also use CSS-style `rgb()` and `rgba()` functions. For consistency with CSS conventions, the red, green and blue values are specified in the range 0-255, and alpha in the range 0-1:

```
rgb(255,0,0) // red
rgba(255,0,0,0.5) // 50% transparent red
```

You can use these literals and functions as part of a more complex expression, for example:

```xml
<UILabel textColor="isSelected ? #00f : #ccc"/>

<UIView backgroundColor="rgba(255, 255, 255, 1 - transparency)"/>
```

The use of color literals is convenient for development purposes, but you are encouraged to define constants for any commonly uses colors in your app, as these will be easier to refactor later.

To supply custom named color constants, you can pass colors in the constants dictionary when loading a layout:

```swift
loadLayout(
    named: "MyLayout.xml",
    constants: [
        "headerColor": UIColor(0.6, 0.5, 0.5, 1),
    ]
)
```

Color constants are available to use in any expression (although they probably aren't much use outside of a color expression).

You can also define a custom colors using extension on `UIColor`, and Layout will detect it automatically:

```swift
extension UIColor {
    static var headerColor =  UIColor(0.6, 0.5, 0.5, 1)
}
```

Colors defined in this way can be referenced by name from inside any color expression, either with or without the `Color` suffix, but are not available inside other expression types:

```xml
<UIView backgroundColor="headerColor"/>

<UIView backgroundColor="header"/>
```


## Images

Static images can be specified by name or via a constant or state variable. As with strings, to avoid the need for nested quotes, image expressions are treated as literal string values, and expressions must be escaped inside `{ ... }` braces:

```xml
<UIImageView image="default-avatar"/>

<UIImageView image="{imageConstant}"/>

<UIImageView image="image_{index}.png"/>
```

## Fonts

Like strings and images, font properties are treated as a literal string and expressions must be escaped with `{ ... }`. Fonts are a little more complicated however, because the literal value is itself a space-delimited value that can encode several distinct pieces of data.

The `UIFont` class encapsulates the font family, size, weight and style, so a font expression can contain any or all of the following space-delimited attributes, in any order:

```
bold
italic
condensed
expanded
monospace
<font-name>
<font-style>
<font-size>
```

Any font attribute that isn't specified will be set to the system default - typically San Francisco 17 point.

The `<font-name>` is a string. It is case-insensitive, and can represent either an exact font name, or a font family. The font name may contain spaces, and can optionally be enclosed in single or double quotes. Use "system" as the font name if you want to use the system font (although this is the default anyway if no name is specified). Here are some examples:

```xml
<UILabel font="courier"/>

<UILabel font="helvetica neue"/>

<UILabel font="'times new roman'"/>
```

The `<font-style>` is a UIFontTextStyle constant, from the following list:

```swift
title1
title2
title3
headline
subheadline
body
callout
footnote
caption1
caption2
```

Specifying one of these values sets the font size to match the user's font size setting for that style, and enables dynamic text sizing, so that changing the font size setting will automatically update the font.

The `<font-size>` can be either a number or a percentage. If you use a percentage value it will either be relative to the default font size (17 points) or whatever size has already been specified in the font expression. For example, if the expression includes a font-style constant, the size will be relative to that. Here are some more examples:

```xml
<UILabel font="Courier 150%"/>

<UILabel font="Helvetica 30 italic"/>

<UILabel font="helvetica body bold 120%"/>
```

`UIFont` constants or variables can also be used via inline expressions. To use a `UIFont` constant called "themeFont", but override its size and weight, you could write:

```xml
<UILabel font="{themeFont} 25 bold"/>
```

## Attributed Strings

Attributed strings work much the same way as regular string expressions, except that you can use inline attributed string constants to create styled text:

```swift
loadLayout(
    named: "MyLayout.xml",
    constants: [
        "styledText": NSAttributedString(string: "styled text", attributes: ...)
    ]
)
```

```xml
<UILabel text="This is some {styledText} embedded in unstyled text" />
```

There is also a really cool extra feature built in to attributed string expressions - they support inline HTML markup:

```swift
LayoutNode(
    view: UILabel(),
    expressions: [
        "text": "I <i>can't believe</i> this <b>actually works!</b>"
    ]
)
```

Using this feature inside an XML attribute would be awkward because the tags would have to be escaped using `&gt;` and `&lt;`, so Layout lets you use HTML *inside* a view node, and it will be automatically assigned to the `attributedText` property of the view:

```xml
<UILabel>This is a pretty <b>bold</b> solution</UILabel>
```

Any lowercase tags are interpreted as HTML markup instead of `LayoutNode` instances. This relies on the built-in `NSMutableAttributedString` HTML parser, which only supports a very minimal subset of HTML, however the following tags are supported:

```xml
<p>, // paragraph
<h1> ... <h6> // heading
<b>, <strong> // bold
<i>, <em> // italic
<u> // underlined
<strike> // strikethrough
<ol>, <li> // ordered list
<ul>, <li> // unordered list
<br/> // linebreak
<sub> // subscript
<sup> // superscript
<center> // centered text
```

And as with regular text attributes, inline HTML can contain embedded expressions, which can themselves contain either attributed or non-attributed string variables or constants:

```xml
<UILabel>Hello <b>{name}</b></UILabel>
```

## Optionals

There is currently very limited support for optionals in expressions. There is no way to specify that an expression's return value is optional, and so returning `nil` from an expression is usually an error. There are a few exceptions to this:

1. Returning nil from a String expression will return an empty string
2. Returning nil from a UIImage expression will return a blank image with zero width/height
3. Returning nil for a delegate or other protocol property is permitted to override the default binding behavior

The reason for these specific exceptions is that passing a nil image or text to a component is a common approach in UIKit for indicating that a given element is not needed, and by allowing nil values for these types, we avoid the need to pass additional flags into the component to mark these as unused.

There is slightly more flexibility when handing optional values *inside* an expression. It is possible to refer to `nil` in an expression, and to compare values against it. For example:

```xml
<UIView backgroundColor="col == nil ? #fff : col"/>
```

In this example, if the `col` constant is `nil`, we return a default color of white instead. This can also be written more simply using the `??` null-coalescing operator:

```xml
<UIView backgroundColor="col ?? #fff"/>
```

# Custom Components

Layout has good support for most built-in UIKit views and view controllers out of the box, but it can also be used with custom UI components that you create yourself. If you follow standard conventions for your view interfaces, then for the most part these should *just work*, however you may need to take some extra steps for full compatibility:


## Namespacing

As you are probably aware, Swift classes are scoped to a particular module. If you have an app called MyApp and it declares a custom `UIView` subclass called `FooView`, then the fully-qualified class name of the view would be `MyApp.FooView`, not just `FooView`, as it would have been in Objective-C.

Layout deals with the common case for you by inserting the main module's namespace automatically if you don't include it yourself. Either of these will work for referencing a custom view in your XML:

```xml
<MyApp.FooView/>

<FooView/>
```

In the interests of avoiding boilerplate, you should generally use the latter form. However, if you package custom components into a separate module then you will need to refer to them using their fully-qualified name in your XML.


## Custom Property Types

As mentioned above, Layout uses the Objective-C runtime to automatically detect property names and types for use with expressions. The Objective-C runtime only supports a subset of possible Swift types, and even for Objective-C types, some runtime information is lost. For example, it's impossible to automatically detect the valid set of raw values and case names for enum types at runtime.

There are also some situations where properties may be exposed in a way that doesn't show up as an Objective-C property at runtime, or the property setter may not be compatible with KVC (Key-Value Coding), resulting in a crash when it is accessed using `setValue(forKey:)`.

To solve this, it is possible to manually expose additional properties and custom setters/getters for views by using an extension. The Layout framework already uses this feature to expose constants for many of the common UIKit enums, but if you are using a 3rd party component, or creating your own, you may need to write an extension to properly support configuration via Layout expressions.

To generate a property type and setter for a custom view, create an extension as follows:

```swift
extension MyView {

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["myProperty"] = RuntimeType(...)
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "myProperty":
            self.myProperty = values as! ...
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}
```

These two overrides add "myProperty" to the list of known expressions for that view, and provide a static setter method for the property.

The `RuntimeType` class shown in the example is a type wrapper used by Layout to work around the limitations of the Swift type system. It can encapsulate information such as the list of possible values for a given enum, which it is not possible to determine automatically at runtime.

`RuntimeType` can be used to wrap any Swift type, for example:

```swift
RuntimeType(MyStructType.self)
```

It can also be used to specify a set of enum values:

```swift
RuntimeType(NSTextAlignment.self, [
    "left": .left,
    "right": .right,
    "center": .center,
])
```

Swift enum values cannot be set automatically using the Objective-C runtime, but if the underlying type of the property matches the `rawValue` (as is the case for most Objective-C APIs) then it's typically not necessary to also provide a custom `setValue(forExpression:)` implementation. You'll have to determine this by testing it on a per-case basis.


# Advanced Topics

## Layout-based Components

If you are creating a library of views or controllers that use Layout internally, it probably doesn't make sense to base each component on a subclass of `LayoutViewController`. Ideally there should only be one `LayoutViewController` visible on-screen at once, otherwise the meaning of "reload" becomes ambiguous.

If the consumers of your component library are using `Layout`, then you could expose all your components as xml files and allow them to be composed directly using Layout templates or code, but if you want the library to work well with an ordinary UIKit app, then it is better if each component is exposed as a regular `UIView` or `UIViewController` subclass.

To implement this, you can make use of the `LayoutLoading` protocol. `LayoutLoading` works in the same way as `LayoutViewController`, providing `loadLayout(...)` and `reloadLayout(...)` methods to load the subviews of your view or view controller using Layout templates.

Unlike `LayoutViewController`,  `LayoutLoading` provides no Red Box error console or reloading keyboard shortcuts, and because it is a protocol rather than a base class, it can be applied on top of any existing `UIView` or `UIViewController` base class that you require.

The default implementation of `LayoutLoading` will bubble errors up the responder chain to the first view or view controller that handles them. If the `LayoutLoading` view or view controller is placed inside a root `LayoutViewController`, it will therefore gain all the same debugging benefits as using a `LayoutViewController` base class:

```swift
class MyView: UIView, LayoutLoading {

    public override init(frame: CGRect) {
        super.init(frame: frame)

        loadLayout(
            named: "MyView.mxl",
            state: ...,
            constants: ...,
        )
    }
}
```

## Manual Integration

If you would prefer not to use either the `LayoutViewController` base class or `LayoutLoading` protocol, you can mount a `LayoutNode` directly into a regular view or view controller by using the `mount(in:)` method:

```swift
class MyViewController: UIViewController {
    var layoutNode: LayoutNode!

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Create a layout node from and XML file or data object
        self.layoutNode = LayoutNode.with(xmlData: ...)

        // Mount it
        try! self.layoutNode.mount(in: self)
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Ensure layout is resized after screen rotation, etc
        try! self.layoutNode.update()
    }
}
```
This method of integration does not provide the automatic live reloading feature for local XML files, nor the Red Box debugging interface - both of those are implemented internally by the `LayoutViewController`.

If you are using some fancy architecture like [Viper](https://github.com/MindorksOpenSource/iOS-Viper-Architecture) that splits up view controllers into sub-components, you may find that you need to bind a `LayoutNode` to something other than a `UIView` or `UIViewController` subclass. In that case you can use the `bind(to:)` method, which will connect the node's outlets, actions and delegates to the specified owner object, but won't attempt to mount the view or view controllers.

The `mount(in:)`, `bind(to:)` and `update()` methods may each throw an error if there is a problem with your XML markup, or in an expression's syntax or logic.

These errors are not expected to occur in a correctly implemented layout - they typically only happen if you have made a mistake in your code - so for release builds it should be OK to suppress them with `try!` or `try?` (assuming you've tested your app properly before releasing it!).

If you are loading XML templates from an external source, you might prefer to catch and log these errors instead of allowing them to crash or fail silently, as there is a greater likelihood of an error making it into production if templates and native code are updated independently.


# Table Views

You can use a `UITableView` inside a Layout template in much the same way as you would use any other view:

```xml
<UITableView
    backgroundColor="#fff"
    outlet="tableView"
    style="plain"
/>
```

The tableView's `delegate` and `dataSource` will automatically be bound to the file's owner, which is typically either your `LayoutViewController` subclass, or the first nested view controller that conforms to one or both of the `UITableViewDelegate`/`DataSource` protocols. If you don't want that behavior, you can explicitly set them (see the [Delegates](#delegates) section above).

You would define the view controller logic for a Layout-managed table in pretty much the same way as you would if not using Layout:

```swift
class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var tableView: UITableView? {
        didSet {

            // Register your cells after the tableView has been created
            // the `didSet` handler for the tableView property is a good place
            tableView?.register(MyCellClass.self, forCellReuseIdentifier: "cell")
        }
    }

    var rowData: [MyModel]

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! MyCellClass
        cell.textLabel.text = rowData.title
        return cell
    }
}
```

Using a Layout-based `UITableViewCell` is also possible. There are two ways to define a `UITableViewCell` in XML - either directly inside your table XML, or in a standalone file. A cell template defined inside the table XML might look something like this:

```xml
<UITableView
    backgroundColor="#fff"
    outlet="tableView"
    style="plain">

    <UITableViewCell
        reuseIdentifier="cell"
        textLabel.text="{title}">

        <UIImageView
            top="50% - height / 2"
            right="100% - 20"
            width="auto"
            height="auto"
            image="{image}"
            tintColor="#999"
        />
    </UITableViewCell>

</UITableView>
```

Then the logic in your table view controller would be:

```swift
class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var rowData: [MyModel]

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Use special Layout extension method to dequeue the node rather than the view itself
        let node = tableView.dequeueReusableCellNode(withIdentifier: "cell", for: indexPath)

        // Set the node state to update the cell
        node.setState(rowData[indexPath.row])

        // Cast the node view to a table cell and return it
        return node.view as! UITableViewCell
    }
}
```

Alternatively, you can define the cell in its own XML file. If you do that, the dequeuing process is the same, but you will need to register it manually:

```swift
class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var tableView: UITableView? {
        didSet {
            // Use special Layout extension method to register the layout xml file for the cell
            tableView?.registerLayout(named: "MyCell.xml", forCellReuseIdentifier: "cell")
        }
    }

    ...
}
```

Layout supports dynamic table cell height calculation. To enable this, just set a height expression for your cell. Dynamic table cell sizing also requires that the table view's `rowHeight` is set to `UITableViewAutomaticDimension` and a nonzero value is provided for `estimatedRowHeight`, but Layout sets these for you automatically. Note that if your cells all have the same height, it is significantly more efficient to set an explicit `rowHeight` property on the `UITableView` instead of setting the height for each cell.

Layout also supports using XML layouts for `UITableViewHeaderFooterView`, and there are equivalent methods for registering and dequeuing `UITableViewHeaderFooterView` layout nodes. **Note:** to use a custom section header or footer you will need to set the         `estimatedSectionHeaderHeight` or `estimatedSectionFooterHeight` to a nonzero value in your XML:

```xml
<UITableView estimatedSectionHeaderHeight="20">

    <UITableViewHeaderFooterView
        backgroundView.backgroundColor="#fff"
        height="auto + 10"
        reuseIdentifier="templateHeader"
        textLabel.text="Section Header"
    />
    
    ...

</UITableView>
```

If you prefer you can create a `<UITableViewController/>` in your XML instead of subclassing `UIViewController` and implementing the table data source and delegate. Note that if you do this, there is no need to explcitly create the `UITableView` yourself, as the `UITableViewController` already includes one. To configure the table, you can set properties of the table view directly on the controller using a `tableView.` prefix, e.g.

```xml
<UITableViewController
    backgroundColor="#fff"
    tableView.separatorStyle="none"
    tableView.contentInset.top="20"
    style="plain">

    <UITableViewCell
        reuseIdentifier="cell"
        textLabel.text="{title}"
    />
</UITableViewController>
```


# Collection Views

Layout supports `UICollectionView` in a similar way to `UITableView`. If you do not specify a custom `UICollectionViewLayout`, Layout assumes that you want to use a `UICollectionViewFlowLayout`, and creates one for you automatically. When using a `UICollectionViewFlowLayout`, you can configure its properties using expressions on the collection view, prefixed with `collectionViewLayout.`:

```xml
<UICollectionView
    backgroundColor="#fff"
    collectionViewLayout.itemSize.height="100"
    collectionViewLayout.itemSize.width="100"
    collectionViewLayout.minimumInteritemSpacing="10"
    collectionViewLayout.scrollDirection="horizontal"
/>
```

As with `UITableView` the collection view's `delegate` and `dataSource` will automatically be bound to the file's owner. Using a Layout-based `UICollectionViewCell`, either directly inside your collection view XML or in a standalone file, also works the same. A cell template defined inside the collection view XML might look something like this:

```xml
<UICollectionView
    backgroundColor="#fff"
    collectionViewLayout.itemSize.height="100"
    collectionViewLayout.itemSize.width="100">

    <UICollectionViewCell
        clipsToBounds="true"
        reuseIdentifier="cell">

        <UIImageView
            contentMode="scaleAspectFit"
            height="100%"
            width="100%"
            image="{image}"
            tintColor="#999"
        />
    </UICollectionViewCell>

</UICollectionView>
```

Then the logic in your collection view controller would be:

```swift
class CollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    var itemData: [MyModel]

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemData.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Use special Layout extension method to dequeue the node rather than the view itself
        let node = collectionView.dequeueReusableCellNode(withIdentifier: "cell", for: indexPath)

        // Set the node state to update the cell
        node.setState(itemData[indexPath.row])

        // Cast the node view to a table cell and return it
        return node.view as! UICollectionViewCell
    }
}
```

Alternatively, you can define the cell in its own XML file. If you do that, the dequeuing process is the same, but you will need to register it manually:

```swift
class CollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    var itemData: [MyModel]

    @IBOutlet var collectionView: UICollectionView? {
        didSet {
            // Use special Layout extension method to register the layout xml file for the cell
            collectionView?.registerLayout(named: "MyCell.xml", forCellReuseIdentifier: "cell")
        }
    }

    ...
}
```

Dynamic collection cell size calculation is also supported. To enable this, just set a width and height expression for your cell. If your cells all have the same size, it is more efficient to set an explicit `collectionViewLayout.itemSize` on the `UICollectionView` instead.

Layout does not currently support using XML to define supplementary `UICollectionReusableView` instances, but this will be added in future.

Layout supports the use of `UICollectionViewController`, with the same caveats as for `UITableViewController`.


## Composition

For large or complex layouts, you may wish to split your layout into multiple files. This can be done easily when creating a `LayoutNode` programmatically, by assigning subtrees of `LayoutNode`s to temporary variables, but what about layouts defined in XML?

Fortunately, Layout has a nice solution for this: any layout node in your XML file can contain an `xml` attribute that references an external XML file. This reference can point to a local file, or even a remote URL:

```xml
<UIView xml="MyView.xml"/>
```

The referenced XML is just an ordinary layout file, and can be loaded and used normally, but when loaded using the composition feature it replaces the node that loads it.

The attributes of the original node will be merged with the external node once it has loaded. Loading is performed asynchronously, so the original node will be displayed first and will be updated once the XML for the external node has loaded. Any children of the original node will be replaced by the contents of the loaded node, so you can insert a placeholder view to be displayed while the real content is loading:

```xml
<UIView backgroundColor="#fff" xml="MyView.xml">
    <UILabel text="Loading..."/>
</UIView>
```

The root node of the referenced XML file must be a subclass of (or the same class as) the node that loads it. You can replace a `<UIView/>` node with a `<UIImageView/>` for example, or a `<UIViewController/>` with a `<UITableViewController/>`, but you cannot replace a `<UILabel/>` with a `<UIButton/>`, or a `<UIView/>` with a `<UIViewController/>`.


## Templates

Templates are sort of the opposite of composition, and work more like class inheritance in OOP. As with the composition feature, a template is a standalone XML file that you import into your node. But when a layout node imports a template, the node's attributes and children are appended to those of the inherited layout, instead of the template node replacing them. This is useful if you have a bunch of nodes with common attributes or elements:

```xml
<UIView template="MyTemplate.xml">
    <UILabel>Some unique content</UILabel>
</UIView>
```

As with composition, the template itself is just an ordinary layout file, and can be loaded and used normally:

```xml
<!-- MyTemplate.xml -->
<UIView backgroundColor="#fff">
    <UILabel>Shared Heading</UILabel>

    <!-- children of the importing node will be inserted here -->
</UIView>
```

Unlike composition, when using a template, the children of both nodes are concatenated rather than one set being replaced. Also, the imported template's root node class must be either the same class or a *superclass* of the importing node (unlike with composition, where it must be the same class or a subclass).

Although you can override the attributes of the root node of an imported template, there is currently no way to override or parameterize the children, apart from by using state variables or constants in the normal fashion.


## Parameters

When using templates, you can configure the root node of the template by setting expressions on the importing node, but this offers rather limited control over customization. Ideally, you want to be able to configure properties of nodes inside the template, and that's where *parameters* come in.

You define parameters by adding `<param/>` nodes inside an ordinary Layout node:

```xml
<!-- MyTemplate.xml -->
<UIView>
    <param name="text" type="String"/>
    <param name="image" type="UIImage"/>

    <UIImageView image="{image}"/>
    <UILabel text="{text}/>
</UIView>
```

Each `<param/>` node has a `name` and `type` attribute. The parameter defines a symbol that can be referenced by any expression defined on the containing node or any of its children.

Parameters can be set using expressions on the importing node:

```xml
<UIView
    template="MyTemplate.xml"
    text="Lorem ipsum sit dolor "
    image="Rocket.png"
/>
```

You can set default values for parameters by defining a matching expression on the containing node. It will be overridden if the same expression is defined on the importing node:

```xml
<!-- MyTemplate.xml -->
<UIView text="Default text">
    <param name="text" type="String"/>
    ...
</UIView>
```


## Ignore File

Every time you load a layout XML file when running in the iOS Simulator, Layout scans your project directory to locate the file. This is usually pretty fast, but if your project has a lot of subfolders then it can take a noticeable time to locate an XML file the first time.

To speed up this scan, you can add a `.layout-ignore` file to your project directory that tells Layout to ignore certain subdirectories. The format of the `.layout-ignore` file is a simple list of file paths (one per line) that should be ignored. You can use `#` to denote a comment, e.g. for grouping purposes:

```
# Ignore these
Tests
Pods
```

File paths are relative to the folder in which the `.layout-ignore` file is placed. Wildcards like `*` are not supported, and the use of relative paths like `../` is not recommended.

Searching begins from the directory containing your `.xcodeproj`, but you can place the `.layout-ignore` file in any subdirectory of your project, and you can include multiple ignore files in different directories.

Layout already ignores invisible files/folders, along with the following directories, so there is no need to include these:

```
build
*.build
*.app
*.framework
*.xcodeproj
*.xcassets
```

The paths listed in `.layout-ignore` will also be ignored by [LayoutTool](#layouttool).


# Example Projects

There are several example projects included with the Layout library:

## SampleApp

The SampleApp project demonstrates a range of Layout features. It is split into four tabs, and the entire project, including the `UITabBarController`, is specified using Layout XML files. The tabs are as follows:

* Boxes - demonstrates use of state to manage an animated layout
* Pages - demonstrates using a `UIScrollView` to create paged content
* Text - demonstrates Layout's text features, include the use of HTML and attributed string constants
* Table - demonstrates Layout's support for `UITableView` and `UITableViewCell`

## UIDesigner

The UIDesigner project is an experimental WYSIWYG tool for constructing layouts. It's written as an iPad app which you can run in the simulator or on a device.

UIDesigner is currently in a very early stage of development. It supports most of the features exposed by the Layout XML format, but lacks import/export, and the ability to specify constants or outlet bindings.

## Sandbox

The Sandbox app is a simple playground for experimenting with XML layouts. It runs on iPhone or iPad.

Like UIDesigner, the Sandbox app currently lacks any load/save or import/export capability, although you can copy and paste XML to and from the edit screen.


# LayoutTool

The Layout project includes the source code for a command-line app called LayoutTool, which provides some useful functions to help with development using Layout. You do not need to install the LayoutTool to use Layout, but you may find it helpful.

## Installation

The latest built binary of LayoutTool is included in the project, and you can just drag-and-drop it to install.

To automatically install LayoutTool into your project using CocoaPods, add the following to your Podfile:

```ruby
pod 'Layout/CLI'
```

This will install the LayoutTool binary inside the `Pods/Layout/LayoutTool` directory inside your project folder. You can then reference this using other scripts in your project.

## Formatting

The main function provided by LayoutTool is automatic formatting of Layout XML files. The `LayoutTool format` command will find any Layout XML files at the specified path(s) and apply standard formatting. You can use the tool as follows:

```
> LayoutTool format /path/to/xml/file(s) [/another/path]
```

For more information, use `LayoutTool help`.

To automatically apply `LayoutTool format` to your project every time it is built, you can add a Run Script build phase that applies the tool. Assuming you've installed the LayoutTool CLI using CocoaPods, that script will look something like:

```bash
"${PODS_ROOT}/Layout/LayoutTool/LayoutTool" format "${SRCROOT}/path/to/your/layout/xml/"
```

The formatting applied by LayoutTool is specifically designed for Layout files. It is better to use LayoutTool for formatting these files rather than a generic XML-formatting tool.

Conversely, LayoutTool is only appropriate for formatting *Layout* XML files. It is not a general-purpose XML formatting tool, and may not behave as expected when applied to arbitrary XML source.

LayoutTool ignores XML files that do not appear to belong to Layout, but if your project contains non-Layout XML files then it is a good idea to exclude these paths from the `LayoutTool format` command, to improve formatting performance and avoid accidental false positives.

To safely determine which files the formatting will be applied to, without overwriting anything, you can use `LayoutTool list` to display all the Layout XML files that LayoutTool can find in your project.

## Renaming

LayoutTool provides a function for renaming classes or expression variables inside one or more Layout XML templates. Use it as follows:

```bash
"${PODS_ROOT}/Layout/LayoutTool/LayoutTool" rename "${SRCROOT}/path/to/your/layout/xml/" oldName newName
```

Only class names and values inside expressions will be affected. HTML elements and literal string fragments are ignored.

**Note:** performing a rename also applies standard formatting to the file. There is currently no way to disable this.


# FAQ

*Q. How is this different from frameworks like [React Native](https://facebook.github.io/react-native/)?

> React Native is a complete x-platform replacement for native iOS and Android development, whereas Layout is a way to build ordinary iOS UIKit apps more easily.

*Q. How is this different from frameworks like [Render](https://github.com/alexdrone/Render)?

> The programming model is very similar, but Layout's runtime expressions mean that you can do a larger proportion of your UI development without needing to restart the Simulator.

*Q. Why does Layout use XML instead of a more modern format like JSON?*

> XML is better to suited to representing document-like structures such as view hierarchies. JSON does not distinguish between node types, attributes and children in its syntax, which leads to a lot of extra verbosity when representing hierarchical structures, as each node must include keys for "type" and "children", or equivalent. JSON also doesn't support comments, which are useful in complex layouts. While XML isn't perfect, it has the fewest tradeoffs of all the formats that iOS has built-in support for.

*Q. Do I really have to write my layouts in XML?*

> You can create `LayoutNode`s manually in code, but XML is the recommended approach for now since it makes it possible to use the live reloading feature. I'm exploring other options, such as alternative formats and GUI tools.

*Q. Is Layout App Store-safe? Has it been used in production?*

> Yes, we have submitted apps using Layout to the App Store, and they have been approved without issue.

*Q. Does Layout support macOS/AppKit?*

> Not currently, but this would make sense in future given the shared language and similar frameworks.

*Q. Why isn't Cmd-R reloading my XML file in the simulator?*

> Make sure that the `Hardware > Keyboard > Connect Hardware Keyboard` option is enabled in the simulator.

*Q. Why do I get an error saying my custom view class isn't recognized?*

> Read the [Namespacing](#namespacing) section above.

*Q. Why do I get an error when trying to set a property of my custom component?*

> Read the [Custom Property Types](#custom-property-types) section above.

*Q. Do I have to use a `LayoutViewController` to display my layout?*

> No. See the [Manual Integration](#manual-integration) section above.

*Q. When I launched my app, Layout asked me to select a source file and I chose the wrong one, now my app crashes on launch. What do I do?

> If the app is red-boxing but still runs, you can reset it with Cmd-Alt-R. If it's actually crashing, the best option is to delete the app from the Simulator, then re-install.
