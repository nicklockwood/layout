[![Travis](https://img.shields.io/travis/nicklockwood/Expression.svg)](https://travis-ci.org/nicklockwood/Expression)
[![License](https://img.shields.io/badge/license-zlib-lightgrey.svg)](https://opensource.org/licenses/Zlib)
[![CocoaPods](https://img.shields.io/cocoapods/p/Expression.svg)](https://cocoapods.org/pods/Expression)
[![CocoaPods](https://img.shields.io/cocoapods/metrics/doc-percent/Expression.svg)](http://cocoadocs.org/docsets/Expression/)
[![Twitter](https://img.shields.io/badge/twitter-@nicklockwood-blue.svg)](http://twitter.com/nicklockwood)


What is this?
----------------

Expression is a library for Mac and iOS for evaluating numeric expressions at runtime.

It is similar to Foundation's built-in Expression class, but with better support for custom operators, and a simpler API.


Why would I want that?
----------------------

There are many situations where it is useful to be able to evaluate a simple expression at runtime. Some such cases are demonstrated in the example apps included with the library:

* A scientific calculator
* A CSS color string parser
* A basic layout engine, similar to AutoLayout

but there are other possible applications, e.g.

* A spreadsheet app
* Configuration (e.g. using expressions in a config file to avoid data duplication)
* The basis for simple scripting language

(If you find any other uses, let me know and I'll add them)

Normally these kind of calculations would involve embedding a heavyweight interpreted language such as JavaScript or Lua into your app. Expression avoids that overhead, and is also more secure as it reduces the risk of arbitrary code injection or crashes due to infinite loops, buffer overflows, etc.

Expression is lightweight, well-tested, and written entirely in Swift 3.


How do I install it?
---------------------

It's just a single class, so you can simply drag the `Expression.swift` file into your project to use it. There's also a framework for Mac and iOS, or you can use CocoaPods or Carthage.


How do I use it?
----------------

You create an `Expression` instance by passing a string containing your expression, and (optionally) any or all of the following:

* A dictionary of named constants - this is the simplest way to specify predefined constants
* A dictionary of symbols and callback functions - this is the most efficient way to provide custom functions or operators
* A custom Evaluator function - this is the most flexible solution, and can support dynamic variable or function names

You can then calculate the result by calling the `Expression.evaluate()` function.

By default, Expression already implements most standard math functions and operators, so you only need to provide a custom symbol dictionary or evaluator function if your app needs to support additional functions or variables.

If you do need to support custom symbols, you should always choose the simplest implementation that meets your requirements, as it will be the fastest to calculate, and provide the most detailed error feedback. Remember you can mix and match implementations, so if you have some custom constants and some custom functions or operators, you can provide separate constants and symbols dictionaries.

Here are some examples:

```swift
// Basic usage:
// Only using built-in math functions

let expression = Expression("5 + 6")
let result = try! expression.evaluate() // 11

// Intermediate usage:
// Custom constants and functions

let expression = Expression("foo + bar(5) + rnd()", constants: [
    "foo": 5,
], symbols: [
    .function("bar", arity: 1): { args in args[0] + 1 },
    .function("rnd", arity: 0): { _ in arc4random() },
])
let result = try! expression.evaluate()

// Advanced usage
// Using a custom Evaluator to decode hex color literals

let hexColor = "#FF0000FF" // rrggbbaa
let expression = Expression(hexColor) { symbol, args in
    if case .constant(let name), name.hasPrefix("#") { {
        let hex = String(name.characters.dropFirst())
        return Double("0x" + hex)
    }
    return nil // pass to default evaluator
}
let color: UIColor = {
    let rgba = UInt32(try! expression.evaluate())
    let red = CGFloat((rgba & 0xFF000000) >> 24) / 255
    let green = CGFloat((rgba & 0x00FF0000) >> 16) / 255
    let blue = CGFloat((rgba & 0x0000FF00) >> 8) / 255
    let alpha = CGFloat((rgba & 0x000000FF) >> 0) / 255
    return UIColor(red: red, green: green, blue: blue, alpha: alpha)
}()
```

Note that the `evaluate()` function can throw an error. An error will be thrown during evaluation if the expression is malformed, or if it references an unknown symbol.

For a simple, hard-coded expression like the first example, there is no possibility of an error being thrown. If you accept user-entered expressions, you must always ensure that you catch and handle errors. The error messages produced by Expression are detailed and human-readable (but not localized, currently).

```swift
do {
    let result = try expression.evaluate()
    print("Result: \(result)")
} catch {
    print("Error: \(error)")
}
```

When using the `constants` and/or `symbols` dictionaries, error message generation is handled automatically by the Expression library. If you need to support dynamic symbol decoding (such as in the hex color example earlier), you will need to use a custom `Evaluator` function, which is a little bit more complex.

Your custom `Evaluator` function can return either a `Double` or `nil` or it can throw an error. If you do not recognize a symbol, you should return nil so that it can be handled by the default evaluator.

In some cases you may be *certain* that a symbol is incorrect, and this is an opportunity to provide a more useful error message. The following example matches a function `bar` with an arity of 1 (meaning that it takes one argument). This will only match calls to bar that take a single argument, and ignore calls with zero or multiple arguments.

```swift
switch symbol {
case .function("bar", arity: 1):
    return args[0] + 1
default:
    return nil // pass to default evaluator
}
```

Since `bar` is a custom function, we know that it should only take one argument, so it is probably more helpful to throw an error if it is called with the wrong number of arguments. That would look something like this:

```swift
switch symbol {
case .function("bar", let arity):
    guard arity == 1 else { throw Expression.Error.arityMismatch(symbol) }
    return args[0] + 1
default:
    return nil // pass to default evaluator
}
```

Note that you can check the arity of the function either using pattern matching (as we did above), or just by checking args.count. These will always match.

    
Symbols
--------------

Expressions are formed from symbols, defined by the `Expression.Symbol` enum type. The default evaluator defines several of these, but you are free to define your own in your custom evaluator function.

The Expression library supports the following symbol types:

```swift
.constant(String)
```

This is an alphanumeric identifier representing a constant or variable in an expression. Identifiers can be any valid sequence of letters and numbers, beginning with a letter, underscore (_), dollar symbol ($), at sign (@) or hash/pound sign (#).

Like Swift, Expression allows unicode characters in identifiers, such as emoji and scientific symbols. Unlike Swift, Expression's identifiers may also contain periods (.) as separators, which is useful for name-spacing (as demonstrated in the Layout example app).

```swift
.infix(String)
.prefix(String)
.postfix(String)
```

These symbols represent operators. Operators can be one or more characters long, and can contain almost any symbol that wouldn't conflict with a valid identifier name. You can overload existing infix operators with a post/prefix variant, or vice-versa. Disambiguation depends on the white-space surrounding the operator (which is the same approach used by Swift).

Any valid identifier may also be used as a postfix operator, by placing it after an operator or literal value. For example, you could define `m` and `cm` as postfix operators when handling distance logic, or `hours`, `minutes` and `seconds` operators for computing times.

Operator precedence follows standard BODMAS order, with multiplication/division given precedence over addition/subtraction. Prefix operators take precedence over postfix operators, which take precedence over infix ones. There is currently no way to specify precedence for custom operators - they all have equal priority to addition/subtraction.

**Note**: Although there are currently no built-in boolean operators, if you wish to implement these then it should work as expected, with the caveat that short-circuiting is not supported. The parser will also recognize the ternary `?:` operator, treating `a ? b : c` as a single infix operator, but with three arguments.


```swift
.function(String, arity: Int)
```

Functions can be defined using any valid identifier followed by a comma-delimited sequence of arguments in parentheses. Functions can be overloaded to support different argument counts, but it is up to you to handle argument validation in your evaluator function.
     
     
Standard library
-------------------

Expression implements a sort of "standard library" in the form of a default symbol dictionary. This contains basic math functions and constants that are generally useful, independent of a particular application.

If you use a custom symbol dictionary, you can override any default symbol, or overload default functions with a different number of arguments (arity). Any symbols from the standard library that you do not explicitly override will still be available. To explicitly disable individual symbols from the standard library, you can override them and throw an exception:

```swift
let expression = Expression("pow(2,3)", symbols: [
    .function("pow", arity: 2): { _ in throw Expression.Error.undefinedSymbol(.function("pow", arity: 2)) }
])
try expression.evaluate() // this will throw an error because pow() has been undefined
```

If you have provided a custom `Evaluator` function, you can fall back to the standard library functions and operators by returning `nil` for unrecognized symbols. If you do not want to provide access to the standard library functions in your expression, throw an `Error` for unrecognized symbols instead of returning `nil`.

```swift
let expression = Expression("3 + 4") { symbol, args in
    switch symbol {
    case .function("foo", arity: 1):
        return args[0] + 1
    default:
        throw Expression.Error.undefinedSymbol(symbol)
    }
}
try expression.evaluate() // this will throw an error because no standard library operators are supported, including +
```

Here is the current supported list of standard library symbols:

**constants**

```swift
pi
```

**infix operators**

```swift
+ - / *
```

**prefix operators**

```swift
-
```

**functions**

```swift
sqrt(x)
floor(x)
ceil(x)
round(x)
cos(x)
acos(x)
sin(x)
asin(x)
tan(x)
atan(x)
abs(x)

pow(x,y)
max(x,y)
min(x,y)
atan2(x,y)
mod(x,y)
```
    
Calculator Example
--------------------

Not much to say about this. It's a calculator. You can type expressions into it, and it will evaluate them and produce a result (or an error, if what you typed was invalid).


Colors Example
----------------

The Colors example demonstrates how to use Expression to create a (mostly) CSS-compliant color parser. It takes a string containing a named color, hex color or rgb() function call, and returns a UIColor object.

Using Expression to parse colors is a bit of a hack, as it only works because it's possible to encode a color as a 32-bit Integer, which itself can be stored inside the Double returned by the Expression Evaluator. Still, it's a neat trick.


Layout Example
----------------

This is where things get interesting: The Layout example demonstrates a crude-but-usable layout system, which supports arbitrary expressions for the coordinates of the views.

It's conceptually similar to AutoLayout, but with some important differences:

* The expressions can be as simple or as complex as you like. In AutoLayout, every constraint uses a choice between a few fixed formulae, where only the operands are interchangeable.
* Instead of applying an arbitrary number of constraints between properties of views, each view just has four fixed properties that can be calculated however you like.
* Layout is deterministic. There is no weighting system used for resolving conflicts, and circular references are forbidden. Despite that, weighted relationships can be achieved using explicit multipliers.

Default layout values for the example views have been set in the Storyboard, but you can edit them live in the app by tapping a view and typing in new values.

Here are some things to note:

* Every view has a `top`, `left`, `width` and `height` expression to define its coordinates on the screen.
* Views have an optional `key` (like a tag, but string-based) that can be used to reference their properties from another view. 
* Any expression-based property of any view can reference any other property (of the same view, or any other view), and can even reference multiple properties.
* Every view has a bottom and right property. These are computed, and cannot be set directly, but they can be used in expressions.
* Circular references (a property whose value depends on itself) are forbidden, and will be detected by the system.
* The `width` and `height` properties can use the `auto` constant, which does nothing useful for ordinary views, but can be used with text labels to calculate the optimal height for a given width, based on the amount of text.
* Numeric values are measured in screen points. Percentage values are relative to the superview's `width` or `height` property.
* Remember you can use functions like `min()` and `max()` to ensure that relative values don't go above or below a fixed threshold.

This is just a toy example, but I think it has some interesting potential. Have fun with it, and maybe even try using `View+Layout.swift` in your own projects. I'll be exploring a more sophisticated implementation of this idea in the future.
