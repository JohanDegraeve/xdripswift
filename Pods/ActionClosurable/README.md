# ActionClosurable

[![Version](https://img.shields.io/cocoapods/v/ActionClosurable.svg?style=flat)](http://cocoapods.org/pods/ActionClosurable)
[![License](https://img.shields.io/cocoapods/l/ActionClosurable.svg?style=flat)](http://cocoapods.org/pods/ActionClosurable)
[![Platform](https://img.shields.io/cocoapods/p/ActionClosurable.svg?style=flat)](http://cocoapods.org/pods/ActionClosurable)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

## Usage

ActionClosurable extends `UIControl`, `UIButton`, `UIRefreshControl`, `UIGestureRecognizer` and `UIBarButtonItem`.
It helps writing swifty code with closure, instead of target and action like below:

```swift
// UIControl
button.on(.touchDown) {
    $0.backgroundColor = UIColor.redColor()
}
button.on(.touchUpOutside) {
    $0.backgroundColor = UIColor.whiteColor()
}
// UIButton
button.onTap {
    $0.enabled = false
}

// UIRefreshControl
tableView.refreshControl = UIRefreshControl { refreshControl in
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        refreshControl.endRefreshing()
    }
}

// UIGestureRecognizer
label.addGestureRecognizer(UIPanGestureRecognizer { (gr) in
    print("UIPanGestureRecognizer fire")
})

// UIBarButtonItem
let barButtonItem = UIBarButtonItem(title: "title", style: .plain) { _ in
    print("barButtonItem title")
}

// And you can easily extend any NSObject subclasses!
```

And you can extend any NSObject subclasses in very easy way. [Refer to the source.](https://github.com/takasek/ActionClosurable/blob/master/ActionClosurable/Extensions.swift)


## Installation

ActionClosurable is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "ActionClosurable"
```
ActionClosurable is available through [Carthage](https://github.com/Carthage/Carthage). To install it, simply add the following line to your Cartfile:

```ruby
github "takasek/ActionClosurable"
```

ActionClosurable is available through [Swift Package Manager](https://github.com/apple/swift-package-manager). To install it, add dependency in `Package.swift`:

```swift
let package = Package(
    ...
    dependencies: [
         .package(url: "git@github.com:takasek/ActionClosurable.git", from: "2.1.0"),
    ],
    ...
)
```

## Author

[takasek](https://twitter.com/takasek)

## License

ActionClosurable is available under the MIT license. See the LICENSE file for more info.
