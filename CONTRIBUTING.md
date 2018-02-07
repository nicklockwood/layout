# Contributing to Layout

So you want to contribute to Layout? That's great!

Here's what you need to know:

## Branches and Versioning

Layout follows the principles of [Semantic Versioning](http://semver.org/spec/v2.0.0.html) (semver), however since Layout is still pre-1.0, the rules are a little less strict. In general, 0.0.x releases are for bug fixes and non-breaking changes, and 0.x.0 releases are for breaking changes. Occasionally, we'll put minor breaking changes into a 0.0.x release if it's unlikely to affect many users.

The Layout repository has 3 main branches:

* master - the currently shipping version
* develop - the next minor release (0.0.x)
* breaking - the next major release (0.x.0)

Many projects use master for development, but users often check master for documentation or to download sample code, so to avoid confusion we want all the code on master to be stable, and for the documentation to reflect the latest tagged version of the Layout framework.

## Your First Pull Request

We know that making your first pull request can be scary. If you have trouble with any of the contribution rules, **make a pull request anyway**. A PR is the start of a process not the end of it.

All types of PR are welcome, but please do read these guidelines carefully to avoid wasting your time and ours. If you are planning something big, or which might be controversial, it's a great idea to create an issue first to discuss it before writing a lot of code.

Types of PR:

* Documentation fixes - if you've found a typo, or incorrect comment, either in the README or a code comment, feel free to create a PR directly against the **master** branch.

* Minor code fixes - a typo in a method name or a trivial bug fix should be made against the **develop** branch. If the fix affects a public API in such a way that it would cause code using that API to no longer compile, it should be made against the **breaking** branch instead.

* Major code changes - significant refactors or new functionality should usually be raised as an issue first to avoid wasted effort on a PR that's unlikely to land. This is mainly for your own sake, not ours, so if you prefer to make suggestions in code form then that's fine too. As with fixes, PRs should be made against **develop** if they are purely additive, or against **breaking** if they break existing public APIs.

* Tooling changes - LayoutTool's version number is kept in sync with the Layout framework. The code for LayoutTool is not part of the public API, so code changes can all be made against **develop**, however the semver rules apply to the command-line interface for LayoutTool, so if your change breaks an existing command-line argument, it should be made against **breaking**.

## Copyright and Licensing

Any new Swift files that you add should include the standard Schibsted copyright header:

```swift
//  Copyright © 2017 Schibsted. All rights reserved.
```

By contributing code to Layout, you are implicitly agreeing to licence it under the terms described in the LICENSE.md file. Please do not submit code that you did not write or are not authorized to redistribute.

Inclusion of 3rd party frameworks is **not** permitted, regardless of the license. Small sections of code copied from somewhere else *may* be acceptable, provided that the terms of the original license are compatible with Layout's LICENSE.md, and that you include a comment linking back to the source.

## Style Guide

We mostly follow the [Ray Wenderlich Style Guide](https://github.com/raywenderlich/swift-style-guide) very closely with the following exception:

- Use the Xcode default of 4 spaces for indentation.

We use [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) to enforce project style automatically before release, so it's not critical that you get it exactly right, but try your best.

## Documentation

Code should be commented, but not excessively. In general, comments should follow the principle of *why, not what*, but it's acceptable to use "obvious" comments as headings to break up large blocks of code. Public methods and classes should be commented using the `///` headerdoc style.

When making public API changes, please update the README.md file if applicable. There is no need to update CHANGELOG.md or bump the version number.

## Tests

All significant code changes should be accompanied by a test.  

Tests are run in [Travis CI](https://travis-ci.org/schibsted/layout) automatically on all pull requests, branches and tags. These are the same tests that run in Xcode at development time.

There is a separate PerformanceTests scheme that you should run manually if your code changes are likely to affect performance.

## Code of Conduct

We don't tolerate rudeness or bullying. If you think somebody else's comment or pull request is stupid, keep it to yourself. If you are frustrated because your issue or pull request isn't getting the attention it deserves, feel free to post a comment like "any update on this?", but remember that we are all busy and our priorites don't necessarily match yours.

Abusive contributors will be blocked and/or reported, regardless of how valuable their code contributions may be.
