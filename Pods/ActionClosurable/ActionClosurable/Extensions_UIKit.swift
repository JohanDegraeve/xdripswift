//
//  Extensions_UIKit.swift
//  ActionClosurable
//
//  Created by Yoshitaka Seki on 2016/04/11.
//  Copyright © 2016年 Yoshitaka Seki. All rights reserved.
//

#if os(iOS)
import UIKit

extension ActionClosurable where Self: UIControl {
    public func on(_ controlEvents: UIControl.Event, closure: @escaping (Self) -> Void) {
        convert(closure: closure, toConfiguration: {
            self.addTarget($0, action: $1, for: controlEvents)
        })
    }
}

extension ActionClosurable where Self: UIButton {
    public func onTap(_ closure: @escaping (Self) -> Void) {
        on(.touchUpInside, closure: closure)
    }
}

public extension ActionClosurable where Self: UIRefreshControl {
    func onValueChanged(closure: @escaping (Self) -> Void) {
        on(.valueChanged, closure: closure)
    }

    init(closure: @escaping (Self) -> Void) {
        self.init()
        onValueChanged(closure: closure)
    }
}


extension ActionClosurable where Self: UIGestureRecognizer {
    public func onGesture(_ closure: @escaping (Self) -> Void) {
        convert(closure: closure, toConfiguration: {
            self.addTarget($0, action: $1)
        })
    }
    public init(closure: @escaping (Self) -> Void) {
        self.init()
        onGesture(closure)
    }
}

extension ActionClosurable where Self: UIBarButtonItem {
    public init(title: String, style: UIBarButtonItem.Style, closure: @escaping (Self) -> Void) {
        self.init()
        self.title = title
        self.style = style
        self.onTap(closure)
    }
    public init(image: UIImage?, style: UIBarButtonItem.Style, closure: @escaping (Self) -> Void) {
        self.init()
        self.image = image
        self.style = style
        self.onTap(closure)
    }
    public init(barButtonSystemItem: UIBarButtonItem.SystemItem, closure: @escaping (Self) -> Void) {
        self.init(barButtonSystemItem: barButtonSystemItem, target: nil, action: nil)
        self.onTap(closure)
    }
    public func onTap(_ closure: @escaping (Self) -> Void) {
        convert(closure: closure, toConfiguration: {
            self.target = $0
            self.action = $1
        })
    }
}
#endif
