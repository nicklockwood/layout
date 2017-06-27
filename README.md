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
    - [Composition](#composition)
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
    - [TableViews](#tableviews)
- [Example Projects](#example-projects)
	- [SampleApp](#sampleapp)
	- [UIDesigner](#uidesigner)
- [FAQ](#faq)

# Introduction

## What?

Layout is a framework for implementing iOS user interfaces using runtime-evaluated expressions for layout and (optionally) XML template files. It is intended as a more-or-less drop-in replacement for Storyboards, but offers a number of advantages.

The Layout framework is *extremely* beta, so expect rough edges and breaking changes.

## Why?

Layout seeks to address a number of issues that make StoryBoards unsuitable for large, collaborative projects, including:

* Proprietary, undocumented format
* Poor composability and reusability
* Difficult to apply common style elements and metric values without copy-and-paste
* Hard for humans to read, and consequently hard to resolve merge conflicts
* Limited WYSIWYG capabilities

Layout also includes a replacement for AutoLayout that aims to be:

* Simpler to use for basic layouts
* More intuitive and readable for complex layouts
* More deterministic and simpler to debug
* More performant (at least in theory :-)

## How?

Layout introduces a new node hierarchy for managing views, similar to the "virtual DOM" used by React Native.

Unlike UIViews (which use NSCoding for serialization), this hierarchy can be deserialized from a lightweight, human-readable XML format, and also offers a concise API for programatically generating view layouts in code when you don't want to use a separate resource file.

View properties are specified using *expressions*, which are simple, pure functions stored as strings and evaluated at runtime. Now, I know what you're thinking - stringly typed code is horrible! - but Layout's expressions are strongly-typed, and designed to fail early, with detailed error messages to help you debug.

Layout is designed to work with ordinary UIKit components, not to replace or reinvent them. Layout-based views can be embedded inside nibs ands storyboards, and nib and storyboard-based views can be embedded inside Layout-based views and view controllers, so there is no need to rewrite your entire app if you want to try using Layout.


# Usage

## Installation

To install Layout using CocoaPods, add the following to the top of your Podfile:

	source 'git@github.schibsted.io:Rocket/cocoapod-specs.git'
	
Then, add the following to the list of pod dependencies:

	pod 'Layout', '~> 0.3.0'

This will include the Layout framework itself, and the open source Expression library, which is the only dependency.

## Integration

The core API exposed by Layout is the `LayoutNode` class. Create a layout node as follows:

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
    
This example code creates a centered `UILabel` inside a `UIView` with a white background that will stretch to fill its superview once mounted.

For simple views, creating the layout in code is a convenient solution that avoids the need for an external file. But the real power of the Layout framework comes from the ability to specify layouts using external XML files because it allows for [live reloading](#live-reloading) (see below), which can significantly reduce development time.

The equivalent XML markup for the above layout is:

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
	
Any built-in iOS view should work when used as an layout XML element. For custom views, see the [Custom Components](#custom-components) section below.

To mount a `LayoutNode` inside a view or view controller, subclass `LayoutViewController` and use one of the following three approaches to load your layout:

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
    
Use option 1 for layouts generated in code. Use option 2 for XML layout files located inside the application resource bundle.

Option 3 can be used to load a layout from an arbitrary URL, which can be either a local file or remotely-hosted. This is useful if you need to develop directly on a device, because you can host the layout file on your Mac and then connect to it from the device to allow reloading of changes without recompiling the app. It's also potentially useful in production for hosting layouts in some kind of CMS system.

**Note:** The `loadLayout(withContentsOfURL:)` offers limited control over caching, etc. so if you intend to host your layouts remotely, it may be better to download the XML template to a local cache location first and then load it from there. 

## Live Reloading

The `LayoutViewController` provides a number of helpful features to improve your development productivity, most notably the *red box* debugger and the *live reloading* option.

If the Layout framework throws an error during XML parsing, node mounting or updating, the `LayoutViewController` will detect it and display the *red box*, which is a full-screen overlay displaying the error message along with a reload button. Pressing reload will reset the layout state and re-load the layout.

When you load an XML layout file in the iOS Simulator, the Layout framework will attempt to find the original source XML file for the layout and load that instead of the static version bundled into the compiled app. This means that you can go ahead and fix the error in your XML file, then reload it *without restarting the simulator, or recompiling the app*.

You can reload at any time, even if there was no error, by pressing Cmd-R in the simulator (not in Xcode itself). `LayoutViewController` will detect that key combination and reload the XML, provided that it is the current first responder on screen.

**Note:** This only works for changes you make to the layout XML file itself, not to Swift code changes in your view controller, or other resources such as images.

This live reloading feature, combined with the gracious handling of errors, means that it should be possible to do most of your interface development without needing to recompile the app. This can be a significant productivity boost.

## Constants

Static XML is all very well, but in the real world, app content is dynamic. Strings, images, and even layouts themselves need to change dynamically based on user generated content, locale, etc.

`LayoutNode` provides two mechanisms for passing dynamic data, which can then be referenced inside your layout expressions; *constants* and *state*.

Constants, as the name implies, are values that remain constant for the lifetime of the `LayoutNode`. The constants dictionary is passed into the `LayoutNode` initializer, and can be referenced by any expression in that node or any of its children.

A good use for constants would be localized strings, or something like colors or fonts used by the app UI theme. These are things that never (or rarely) change during the lifecycle of the app, so its acceptable that the view hierarchy must be torn down in order to reset them.

Here is how you would pass some constants inside `LayoutViewController`:

	self.loadLayout(
	    named: "MyLayout.xml",
	    constants: [
	    	"title": NSLocalizedString("homescreen.title", message: ""),
	    	"titleColor": UIColor.primaryThemeColor,
	    	"titleFont": UIFont.systemFont(ofSize: 30),
	    ]
	)

And how you might reference them in the XML:

	<UIView ... >
		<UILabel
			width="100%"
			textColor="titleColor"
			font="{titleFont}"
			text="{title}"
		/>
	</UIView>

(You may have noticed that the `title` and `titleFont` constants are surrounded by `{...}` braces, but the `titleColor` constant isn't. This is explained in the [Strings](##strings) and [Fonts](##fonts) subsections below.)

You will probably find that some constants are common to every layout in your application, for example if you have constants representing standard spacing metrics, fonts or colors. It would be annoying to have to repeat these everywhere, but the lack of a convenient way to merge dictionaries in Swift (as of version 3.0) makes it painful to create a static dictionary of common constants as well.

For this reason, the `constants` argument of `LayoutNode`'s initializer is actually variadic, allowing you to pass multiple dictionaries, which will be merged automatically. This makes it much more pleasant to combine a standard constants dictionary with a handful of custom values:

    let extraConstants: [String: Any] = ...

    self.loadLayout(
	    named: "MyLayout.xml",
	    constants: globalConstants, extraConstants, [
	    	"title": NSLocalizedString("homescreen.title", message: ""),
	    	"titleColor": UIColor.primaryThemeColor,
	    	"titleFont": UIFont.systemFont(ofSize: 30),
	    ]
	)


## State

For more dynamic layouts, you may have properties of the view that need to change frequently (perhaps even during an animation), and recreating the entire view hierarchy to change these is neither convenient nor efficient. For these properties, you can use *state*. State works the same way as constants, except you can update state after the `LayoutNode` has been initialized:

	self.loadLayout(
	    named: "MyLayout.xml",
	    state: [
	    	"isSelected": false,
	    ],
	    constants: [
	    	"title": ...
	    ]
	)
	
	func setSelected() {
		self.layoutNode.state = ["isSelected": true]
	}
	
Note that you can used both constants and state in the same Layout. If a state variable has the same name as a constant, the state variable takese precedence.

Although state can be updated dynamically, all state properties must be given default values when the `LayoutNode` is first initialized. Adding or removing state properties later on is not permitted. 

As with constants, state values can be passed in at the root node of a hierarchy and accessed by any child node. If children in the hierarchy have their own state properties then these will take priority over values set on their parents.

When setting state, you do not have to pass every single property. If you are only updating one property, it is fine to pass a dictionary with only that key/value pair.

Setting the `state` property of a `LayoutNode` after it has been created will trigger an update. The update causes all expressions in that node and its children to be re-evaluated. In future it may be possible to detect if parent nodes are indirectly affected by the state changes of their children and update them too, but currently that is not implemented.

In the examples above, we've used a dictionary to store the state values, but `LayoutNode` supports the use of arbitrary objects for state. A really good idea for layouts with complex state requirements is to use a `struct` to store the state. When you set the state using a `struct` or `class`, Layout uses Swift's introspection features to compare changes and determine if an update is necessary.

Internally the `LayoutNode` still just treats the struct as a dictionary of key/value pairs, but you get to take advantage of compile-time type validation when manipulating your state programmatically in the rest of your program:

	struct LayoutState {
		let isSelected: Bool
	}

	self.loadLayout(
	    named: "MyLayout.xml",
	    state: LayoutState(isSelected: false),
	    constants: [
	    	"title": ...
	    ]
	)
	
	func setSelected() {
		self.layoutNode.state = LayoutState(isSelected: false)
	}


## Actions

For any non-trivial view you will need to bind actions from controls in your view hierarchy to your view controller, and communicate changes back to the view.

You can define actions on any `UIControl` subclass using `actionName="methodName"` in your XML, for example:

    <UIButton touchUpInside="wasPressed"/>
    
Layout uses a little-known feature of iOS called the *responder chain* to broadcast that action up the view hierarchy. It will then be intercepted by whichever is the first parent view or view controller that implements a compatible method, in this case:

    func wasPressed() {
        ...
    }
    
The actions's method name follows the Objective-C selector syntax, so if you wish to pass the button itself as a sender, use a trailing colon in the method name:

	<UIButton touchUpInside="wasPressed:"/>
	
Then the corresponding method can be implemented as:

    func wasPressed(_ button: UIButton) {
        ...
    }

A downside of this approach is that no error is generated if your action method is misnamed - it will simply fail to be called when the button is pressed. It's possible that a future version of Layout will detect this situation and treat it as an error.

## Outlets

The corresponding feature to action binding is *outlets*. When creating views inside a Nib or Storyboard, you typically create references to individual views by using properties in your view controller marked with the `@IBOutlet` attribute.

This mechanism works pretty well, so Layout copies it wholesale, but with a few small enhancements. To create an outlet binding for a layout node, just declare a property of the correct type on your `LayoutViewController`, and then reference it using the `outlet` constructor argument for the `LayoutNode`:

    class MyViewController: LayoutViewController {
    
    	var labelNode: LayoutNode!
    
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
    
In this example we've bound the `LayoutNode` containing the `UILabel` to the `labelNode` property. A few things to note:

* There's no need to use the `@IBOutlet` attribute for your outlet property, but you can do so if you feel it makes the purpose clearer
* The type of the outlet property can be either `LayoutNode` or a `UIView` subclass that's compatible with the view used in the node. The syntax is the same in either case - the type will be checked at runtime, and an error will be thrown if it doesn't match up.
* In the example we have used Swift's `#keyPath` syntax for the outlet value for better static validation. This is recommended, but not required.
	
It is also possible to specify outlet bindings when using XML templates as follows:

	<UIView>
		<UILabel
			outlet="labelNode"
			text="Hello World"
		/>
	</UIView>

In this case we lose the static validation provided by `#keyPath`, but Layout still performs a runtime check and will throw a graceful error in the event of a typo or type mismatch, rather than crashing.

## Delegates

Another common pattern used commonly in iOS views is the *delegate* pattern. Layout also supports this, but it does so in an implicit way that may be confusing if you aren't expecting it.

When loading a layout XML file, or a programmatically-created `LayoutNode` hierarchy into a `LayoutViewController`, the views will be scanned for delegate properties and these will be automatically bound to the `LayoutViewController` *if* it conforms to the specified protocol.

So for example, if your layout contains a `UIScrollView`, and your view controller conforms to the `UIScrollViewDelegate` protocol, then the view controller will automatically be attached as the delegate for the view controller. It's that simple!

	class MyViewController: LayoutViewController, UITextFieldDelegate {
    
    	var labelNode: LayoutNode!
    
        public override func viewDidLoad() {
        	super.viewDidLoad()
        	
        	self.layoutNode = LayoutNode(
        		view: UIView()
        		children: [
        			LayoutNode(
        				view: UItextField(), // delegate is automatically bound to MyViewController
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

There are a few caveats to watch out for, however:

* This mechanism currently only works for properties called "delegate" or "dataSource". These are the standard names used by UIKit components, but if you have a custom control that uses a different name for its delegate, it won't work automatically.

* The binding mechanism relies on Objective-C runtime protocol detection, so it won't work for Swift protocols that aren't `@objc`-compliant.

* If you have multiple views in your layout that all use the same delegate protocol, e.g. several `UIScrollView`s or several `UITextField`s then they will *all* be bound to the view controller. If you are only interested in receiving events from some views and not others, you will need to add logic inside the delegate method implementations to determine which view is calling it. That may involve adding additional outlets in order to distinguish between views.

## Composition

For large or complex layouts, you may wish to split your layout into multiple files. This can be done easily when creating a `LayoutNode` programmatically, by assigning subtrees of `LayoutNode`s to a temporary variable, but what about layouts defined in XML?

Fortunately, Layout has a nice solution for this. Any layout node in your XML file can contain an `xml` attribute that references an external XML file. This reference can point to a local file, or even a remote URL:

	<UIView xml="MyView.xml"/>
	
The attributes of the original node will be merged with the external node once it has loaded. Any children of the original node will be replaced by the contents of the loaded node, so you can insert a placeholder view to be displayed while the real content is loading:

	<UIView backgroundColor="#fff" xml="MyView.xml">
		<UILabel text="Loading..."/>
	</UIView>


# Expressions

The most important feature of the `LayoutNode` class is its built-in support for parsing and evaluating expressions. The implementation of this feature is built on top of the [Expression](https://github.com/nicklockwood/Expression) framework, but Layout adds a number of extensions in order to support arbitrary types and layout-specific logic.

Expressions can be simple, hard-coded values such as "10", or more complex expressions such as "width / 2 + someConstant". The available operators and functions to use in an expression depend on the name and type of the property being expressed, but in general all expressions support the standard decimal math and boolean operators and functions that you find in most C-family programming languages.
	
Expressions in a `LayoutNode` can reference constants and state passed in to the node or any of its parents. They can also reference the values of any other expression defined on the node, or any supported property of the view:

    5 + width / 3
    isSelected ? blue : gray
	min(width, height)
	a >= b ? a : b
	pi / 2
	
Additionally, a node can reference properties of its parent node using `parent.someProperty`, or of its immediate sibling nodes using `previous.someProperty` and `next.someProperty`.

## Layout Properties

The set of expressible properties available to a `LayoutNode` depends on the view, but every node supports the following properties at a minimum:

	top
	left
	bottom
	right
	width
	height
	
These are numeric values (measured in screen points) that specify the frame for the view. In addition to the standard operators, all of these properties allow values specified in percentages:

	<UIView right="50%"/>
	
Percentage values are relative to the width or height of the parent `LayoutNode` (or the superview, if the node has no parent). The expression above is equivalent to writing:

	<UIView right="parent.width / 2">
	
Additionally, the `width` and `height` properties can make use of a virtual variable called `auto`. The `auto` variable equates to the content width or height of the node, which is determined by a combination of three things:

* The `intrinsicContentSize` property of the native view (if specified)
* Any AutoLayout constraints applied to the view by its (non-Layout-managed) subviews
* The enclosing bounds for all the children of the node.

If a node has no children and no intrinsic size, `auto` is equivalent to `100%`.

Though entirely written in Swift, the Layout library makes heavy use of the Objective-C runtime to automatically generate property bindings for any type of view. The available properties therefore depend on the view class that is passed into the `LayoutNode` constructor (or the name of the XML node, if you are using XML layouts).

Only types that are visible to the Objective-C runtime can be detected automatically. Fortunately, since UIKit is an Objective-C framework, most view properties work just fine. For ones that don't, it is possible to manually expose these using an extension on the view (this is covered below under Advanced Topics).

Because it is possible to pass in arbitrary values via constants and state, Layout supports referencing almost any type of value inside an expression, even if there is no way to express it as a literal.

Expressions are strongly-typed however, so passing the wrong type of value to a function or operator, or returning the wrong type from an expression will result in an error. Where possible, these type checks are performed immediately when the node is first created so that the error is surfaced immediately.

The following types of property are given special treatment in order to make it easier to specify them using an expression string:

## Geometry

Because Layout manages the view frame automatically, direct manipulation of the view's frame and position via expressions is not permitted - you should use the `top`/`left`/`bottom`/`right`/`width`/`height` expressions instead. However, there are other geometric properties that do not directly affect the frame, and many of these *are* available to be set via expressions, for example:

* contentSize
* contentInset
* layer.transform

These properties are not simple numbers, but structs containing several packed values. So how can you manipulate these with Layout expressions?

Well, first of all, almost any property type can be set using a constant or state variable, even if there is no way to define a literal value in an expression. So for example, the following code will set the `layer.transform` even though Layout has no built-support for manipulating `CATransform3D` matrices:

	LayoutNode(
		named: "MyLayout.xml",
		state: [
			"flipped": true
		],
	    constants: [
	    	"identityTransform": CATransform3DIdentity,
	    	"flipTransform": CATransform3DMakeScale(1, 1, -1)
	    ]
	)
	
	<UIView layer.transform="flipped ? flipTransform : identityTransform"/>
	
But for some of the more common geometry types, such as `CGPoint`, `CGSize`, `CGRect` and `UIEdgeInsets`, Layout has built-in support for directly referencing the member properties in expressions. To set the top `contentInset` value for a `UIScrollView`, you could use:
	
	<UIScrollView contentInset.top="topLayoutGuide.length + 10"/>
	
And to explicitly set the `contentSize`, you could use:

	<UIScrollView
		contentSize.width="200%"
		contentSize.height="auto + 20"
	/>
	
(Note that `%` and `auto` are permitted inside `contentSize.width` and `contentSize.height`, just as they are for `width` and `height`.)
	

## Strings

It is often necessary to use literal strings inside an expression, and since expressions themselves are typically wrapped in quotes, it would be annoying to have to used nested quotes every time. For this reason, string expressions are treated as literal strings by default, so in this example...

	<UILabel text="title"/>
	
...the `text` property of the label has been given the literal value "title", and not the value of a constant named "title", as you might expect.

To use an expression inside a string property, escape the value using `{ ... }` braces. So to use the "title" constant instead, you would write this:

	<UILabel text="{title}"/>
	
You can use arbitrary logic inside the braced expression block, including maths and boolean comparisons. The value of the expressions need not be a string, as the result will be *stringified*. You can use multiple expression blocks inside a single string expression, and mix and match expression blocks with literal segments:

	<UILabel text="Hello {name}, you have {n + 1} new messages"/>
	
If you need to use a string literal *inside* an expression block, then you can use single or double quotes to escape it:

	<UILabel text="Hello {hasName ? name : 'World'}"/>

If your app is localized, you will need to use constants instead of literal strings for virtually all of the strings in your template. Localizing all of these strings and passing them as individual constants would be rather tedious, so Layout offers some alternatives:

Constants prefixed with `strings.` are assumed to be localized strings, and will be looked up in the application's `Localizable.strings` file. So for example, if your `Localizable.strings` file contains the following entry:

    "Signup.NameLabel" = "Name";
    
Then you can reference this directly in your XML as follows, without creating an explicit constant in code:

    <UILabel text="{strings.Signup.NameLabel}"/>
    
It's common practice on iOS to use the English text as the key for localized strings, which may often contain spaces of punctuation making it invalid as an identifier. In this case, you can use backticks to escape the key, as follows:

    <UILabel text="{`strings.Some text with spaces and punctuation!`}"/>

In addition to reducing boilerplate, strings referenced directly from your XML will also take advantage of [live reloading](#live-reloading), so you can make changes to your `Localizable.strings` file, and they will be picked up when you type Cmd-R in the simulator, with no need to recompile the app.

	
## Colors

Colors can be specified using CSS-style rgb(a) hex literals. These can be 3, 4, 6 or 8 digits long, and are prefixed with a `#`:

	#fff // opaque white
	#fff7 // 50% transparent white
	#ff0000 // opaque red
	#ff00007f // 50% transparent red

You can also use CSS-style `rgb()` and `rgba()` functions. For consistency with CSS conventions, the red, green and blue values are specified in the range 0-255, and alpha in the range 0-1:

	rgb(255,0,0) // red
	rgba(255,0,0,0.5) // 50% transparent red
	
You can use these literals and functions as part of a more complex expression, for example:

	<UILabel textColor="isSelected ? #00f : #ccc"/>

	<UIView backgroundColor="rgba(255, 255, 255, 1 - transparency)"/>
	
The use of color literals is convenient for development purposes, but you are encouraged to define constants for any commonly uses colors in your app, as these will be easier to refactor later. 
	
## Images

Static images can be specified by name or via a constant or state variable. As with strings, to avoid the need for nested quotes, image expressions are treated as literal string values, and expressions must be escaped inside `{ ... }` braces:

	<UIImageView image="default-avatar"/>
		
	<UIImageView image="{imageConstant}"/>
	
	<UIImageView image="image_{index}.png"/>

## Fonts

Like strings and images, font properties are treated as a literal string and expressions must be escaped with `{ ... }`. Fonts are a little more complicated however, because the literal value is itself a space-delimited value that can encode several distinct pieces of data.

The `UIFont` class encapsulates the font family, size, weight and style, so a font expression can contain any or all of the following space-delimited attributes, in any order:

	bold
	italic
	condensed
	expanded
	monospace
	<font-name>
	<font-size>
	
The foont name is a string and font size is a number. Any attribute that isn't specified will be set to the system default - typically 17pt San Francisco. Here are some examples:

	<UILabel font="bold"/>
	
	<UILabel font="Courier 15"/>
	
	<UILabel font="Helvetica 30 italic"/>

These literal properties can be mixed with inline expressions, so for example to override the weight and size of a `UIFont` constant called "themeFont" you could use:

	<UILabel font="{themeFont} {size} bold"/>

## Attributed Strings

Attributed strings work much the same way as regular string expressions, except that you can use inline attributed string constants to create styled text:
	
	loadLayout(
	    named: "MyLayout.xml",
	    constants: [
	    	"styledText": NSAttributedString(string: "styled text", attributes: ...)
	    ]
	)
	
	<UILabel text="This is some {styledText} embedded in unstyled text" />
	
However, there is a really cool extra feature built in to attributed string expressions - they support inline HTML markup:

	LayoutNode(
	    view: UILabel(),
	    expressions: [
	    	"text": "I <i>can't believe</i> this <b>actually works!</b>"
	    ]
	)

Using this feature inside an XML attribute would be awkward because the tags would have to be escaped using `&gt` and `&lt;`, so Layout lets you use HTML inside a view node, and it will be automatically assigned to the `attributedText` expression:

	<UILabel>This is a pretty <b>bold</b> solution</UILabel>
	
Any lowercase tags are interpreted as HTML markup instead of a `UIView` class. This  relies on the built-in `NSMutableAttributedString` HTML parser, which only supports a very minimal subset of HTML, however the following tags are all supported:
	
	<p>, // paragraph
	<h1>, <h2>, etc // heading
	<b>, <strong> // bold
	<i>, <em> // italic
	<u> // underlined
	<ol>, <li> // ordered list
	<ul>, <li> // unordered list
	<br/> // linebreak
	
And as with regular text attributes, inline HTML can contain embedded expressions, which can themselves contain either attributed or non-attributed string variables or constants:

	<UILabel>Hello <b>{name}</b></UILabel>

## Optionals

There is currently very limited support for optionals in expressions. There is no way to specify that an expression's return value is optional, and so returning `nil` from an expression is usually an error. There are two exceptions to this:

1. Returning nil from a String expression will return an empty string
2. Returning nil from a UIImage expression will return a blank image with zero width/height

The reason for these specific exceptions is that passing a nil image or text to a component is a common approach in UIKit for indicating that a given element is not needed, and by allowing nil values for these types, we avoid the need to pass additional flags into the component to mark these as unused.

There is slightly more flexibility when handing optional values *inside* an expression. It is possible to refer to `nil` in an expression, and to compare values against it. For example:

    <UIView backgroundColor="col == nil ? #fff : col"/>
    
In this example, if the `col` constant is `nil`, we return a default color of white instead. This can also be written more simply using the `??` null-coalescing operator:

    <UIView backgroundColor="col ?? #fff"/>


# Custom Components

Layout has good support for most built-in UIKit views and view controllers out of the box, but it can also be used with custom UI components that you create yourself. If you follow standard conventions for your view interfaces, then for the most part these should *just work*, however you may need to take some extra steps for full compatibility:

## Namespacing

As you are probably aware, Swift classes are name-spaced to a particular module. If you have an app called MyApp and it declares a custom `UIView` subclass called `FooView`, then the fully-qualified class name of the view would be `MyApp.FooView`, and not just `FooView` as it would have been in Objective-C.

Layout deals with the common case for you by inserting the main module's namespace automatically if you don't include it yourself. Either of these will work for referenceing a custom view in your XML:

	<MyApp.FooView/>
	
	<FooView/>
	
And generally, in the interests of avoiding boilerplate, you should use the latter form. However, if you package custom components into a separate module (as we have done with the Northstar components in the SampleApp) then you will need to refer to them using their fully-qualifed name in your XML.

## Custom Property Types

As mentioned above, Layout uses the Objective-C runtime to automatically detect property names and types for use with expressions. The Objective-C runtime only supports a subset of possible Swift types, and even for Objective-C types, some runtime information is lost. For example, it's impossible to autoamtically detect the valid set of values and case names for enum types.

There are also some situations where properties may be exposed in a way that doesn't show up as an Objective-C property at runtime, or the property setter may not be compatible with KVC (Key-Value Coding), resulting in a crash when it is accessed using `setValue(forKey:)`.

To solve this, it is possible to manually expose additional properties and custom setters/getters for views by using an extension. The Layout framework already uses this feature to expose constants for many of the common UIKit enums, but if you are using a 3rd party component, or creating your own, you may need to write an extension to properly support configuration via Layout expressions.

To generate a property type and setter for a custom view, create an extension as follows:

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
	
These two overrides add "myProperty" to the list of known expressions for that view, and provide a static setter method for the property.

The `RuntimeType` class shown in the example is a type wrapper used by Layout to work around the limitations of the Swift type system. It can encapsulate information such as the list of possible values for a given enum, which it is not possible to determine automatically at runtime.

`RuntimeType` can be used to wrap any Swift type, for example:

	RuntimeType(MyStructType.self)
	
It can also be used to specify a set of enum values:

	RuntimeType(NSTextAlignment.self, [
        "left": .left,
        "right": .right,
        "center": .center,
    ])

Swift enum values cannot be set automatically using the Objective-C runtime, but if the underlying type of the property matches the `rawValue` (as is the case for most Objective-C APIs) then it's typically not necessary to also provide a custom `setValue(forExpression:)` implementation. You'll have to determine this on a per-case basis.


# Advanced Topics

## Layout-based Components

If you are creating a library of views or controllers that use Layout internally, it probably doesn't make sense to base each component on a subclass of `LayoutViewController`. Ideally there should only be one `LayoutViewController` visible on-screen at once, otherwise the meaning of "reload" becomes ambiguous.

If the consumers of your component library are using `Layout`, then you can expose all your components as xml files and allow them to be composed directly using Layout templates or code, but if you want the library to work well with ordinary UIKit code, then it is better if each component is exposed as a regular `UIView` or `UIViewController` subclass.

To implement this, you can make use of the `LayoutLoading` protocol. `LayoutLoading` works in the same way as `LayoutViewController`, providing `loadLayout(...)` and `reloadLayout(...)` methods to load the subviews of your view or view controller using Layout templates.

Unlike `LayoutViewController`,  `LayoutLoading` provides no "red box" error console or reloading keyboard shortcuts, and because it is a protocol rather than a base class, it can be applied on top of any existing `UIView`/`ViewController` base class that you require.

The default implementations of `LayoutLoading` will bubble errors up the responder chain to the first view or view controller that handles them. If the `LayoutLoading` view or view controller is placed inside a root `LayoutViewController`, it will therefore gain all the same debugging benefits of using a `LayoutViewController` base class, but with less overhead and more flexibility.

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


## Manual Integration

If you would prefer not to use either the `LayoutViewController` base class or `LayoutLoading` protocol, you can mount a `LayoutNode` directly into a regular view or view controller by using the `mount(in:)` method:
	
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

This method of integration does not provide the automatic live reloading feature for local XML files, nor the "red box" debugging interface - both of those are implemented internally by the `LayoutViewController`. It also won't bubble errors up the responder chain to the next `LayoutLoading` handler.

Both the `mount(in:)` and `update()` methods may throw an error. An error will be thrown if there is a problems with your XML markup, or in an expression's syntax or logic.

These errors are not expected to occur in a correctly implemented layout - they typically only happen if you have made a mistake in your code, so it should be OK to suppress them with `!` for release builds (assuming you've tested your app before releasing it!).

If you are loading XML templates from a external source, you may wish to catch and log errors instead of allowing them to crash, as there is a greater likelihood of an error making it into production if templates and native code are updated independently.
    
# TableViews

You can use a `UITableView` inside a Layout template in much the same way as you would use any view. The delegate and datasource will automatically be bound to the file's owner, which is typically either the `LayoutViewController`, or the first nested view controller that conforms to one or both of the `UITableViewDelegate`/`DataSource` protocols.

Using a Layout-based `UITableViewCell` is also possible, but slightly more involved. Currently, the implementation for a Layout-based table must be done primarily in code rather than in the layout template itself. A typical setup might look like this:

    class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
        @IBOutlet var tableView: UITableView? {
            didSet {
                tableView?.registerLayout(
                    named: "MyCell.xml",
                    forCellReuseIdentifier: "cell"
                )
            }
        }
        
        var rowData: [MyModel]
    
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return rowData.count
        }
    
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let node = tableView.dequeueReusableLayoutNode(withIdentifier: "cell", for: indexPath)
            node.state = rowData[indexPath.row]
            return node.view as! UITableViewCell
        }
    }
    
Note the use of two extension methods on `UITableview`: `registerLayout(...)` and `dequeueReusableLayoutNode(...)`. These work in pretty-much the same way as their UIKit counterparts, but are desiged to work with xml Layout-based cells instead of nibs.

The XML for the cell itself might look something like this:

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


# Example Projects

There are two example projects includes with the Expression library. These use CocoaPods for integration, however the pod directories are included in the repository, so they should be ready to run.

## SampleApp

The SampleApp project demonstrates a range of Layout features. It is split into four tabs, and the entire project, including the `UITabBarController`, is specified in a single Layout.xml file with a single view controller to manage the layout. The tabsPare as follows:

* Boxes - demonstrates use of state to manage an animated layout
* Pages - demonstrates using a `UIScrollView` to create paged content
* Text - demonstrates Layout's text features, include the use of HTML and attributed string constants
* Northstar - demonstrates how Layout can be used to build a real-world layout using the Northstar components

## UIDesigner

The UIDesigner project is an experimental WYSIWYG tool for constructing layouts. It's written as an iPad app which you can run in the simulator or on a device.

UIDesigner is currently in a very early stage of development. It supports most of the features exposed by the Layout XML format, but lacks import/export, and the ability to specify constants or outlet bindings.

# FAQ

*Q. Why isn't Cmd-R reloading my XML file in the simulator?*

> Make sure that the `Hardware > Keyboard > Connect Hardware Keyboard` option is enabled in the simulator.

*Q. Why do I get an error saying my custom view class isn't recognized?*

> Read the [Namespacing](#namespacing) section above.

*Q. Why do I get an error when trying to set a property of my custom component?*

> Read the [Custom Property Types](#custom-property-types) section above.

*Q. Do I have to use a `LayoutViewController` to display my layout?*

> No. See the [Manual Integration](#manual-integration) section above.

*Q. Do I really have to write my layouts in XML?*

> You can create `LayoutNode`s manually in code, but XML is the recommended approach for now. I'm exploring other options such as other formats and GUI tools.
