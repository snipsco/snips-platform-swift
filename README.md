# snips-platform-swift

[![Build Status](https://travis-ci.org/snipsco/snips-platform-swift.svg?branch=master)](https://travis-ci.org/snipsco/snips-platform-swift)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#carthage)
![Swift 4.1.x](https://img.shields.io/badge/Swift-4.1.x-orange.svg)
![platforms](https://img.shields.io/badge/platforms-iOS%20-lightgrey.svg)

The Swift framework for the Snips Platform

## Installation

SnipsPlatform supports iOS 11.0+.

#### Carthage

If you use [Carthage][] to manage your dependencies, simply add snips-platform-swift to your Cartfile:

```
github "snipsco/snips-platform-swift"
```

If you use Carthage to build your dependencies, make sure you have added `SnipsPlatform.framework` into the "Linked Frameworks and Libraries" section of your target, and have included them in your Carthage framework copying build phase.

#### Cocoapods

If you use [CocoaPods][] to manage your dependencies, 

First you'll need to add the Snips source repo at the top of your Podfile:
```
source 'https://github.com/snipsco/Specs'
```

Then symply add SnipsPlatform to your Podfile:
```
pod 'SnipsPlatform'
```

#### Git submodule

 1. Add the snips-platform-swift repository as a [submodule][] of your application’s repository.
 1. Run `git submodule update --init --recursive` from within the snips-platform-swift folder.
 1. Drag and drop `SnipsPlatform.xcodeproj` into your application’s Xcode project or workspace.
 1. On the “General” tab of your application target’s settings, add `SnipsPlatform.framework` to the “Embedded Binaries” section.

#### Build for Xamarin
• Add `@objc(SnipsPlatform)` on top of the SnipsPlatform class
• Inherit `SnipsPlatform: NSObject`
• Change SnipsPlatform Run to Release.
• Menu Product > Build for > Running
• Navigate to product
• Copy Release-iphoneos/NAME.framework to NAME.framework
• Create the FAT library using:
• lipo -create Release-iphonesimulator/NAME.framework/NAME Release-iphoneos/NAME.framework/NAME -output NAME.framework/NAME
• Copy the files in Release-iphonesimulator/NAME.framework/Modules/NAME.swiftmodule to NAME.framework/Modules/NAME.swiftmodule (until now it only contained files from the iphoneos)

## License

Licensed under either of
 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.

[Carthage]: https://github.com/Carthage/Carthage
[CocoaPods]: https://cocoapods.org/
[submodule]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
