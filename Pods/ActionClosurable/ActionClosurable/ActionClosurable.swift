//
//  ActionClosurable.swift
//  ActionClosurable
//
//  Created by Yoshitaka Seki on 2016/04/11.
//  Copyright © 2016年 Yoshitaka Seki. All rights reserved.
//

import Foundation

private class Actor<T> {
    @objc func act(sender: AnyObject) { closure(sender as! T) }
    fileprivate let closure: (T) -> Void
    init(acts closure: @escaping (T) -> Void) {
        self.closure = closure
    }
}

private class GreenRoom {
    fileprivate var actors: [Any] = []
}
private var GreenRoomKey: UInt32 = 893

private func register<T>(_ actor: Actor<T>, to object: AnyObject) {
    let room = objc_getAssociatedObject(object, &GreenRoomKey) as? GreenRoom ?? {
        let room = GreenRoom()
        objc_setAssociatedObject(object, &GreenRoomKey, room, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return room
        }()
    room.actors.append(actor)
}

public protocol ActionClosurable {}
public extension ActionClosurable where Self: AnyObject {
    func convert(closure: @escaping (Self) -> Void, toConfiguration configure: (AnyObject, Selector) -> Void) {
        let actor = Actor(acts: closure)
        configure(actor, #selector(Actor<AnyObject>.act(sender:)))
        register(actor, to: self)
    }
    static func convert(closure: @escaping (Self) -> Void, toConfiguration configure: (AnyObject, Selector) -> Self) -> Self {
        let actor = Actor(acts: closure)
        let instance = configure(actor, #selector(Actor<AnyObject>.act(sender:)))
        register(actor, to: instance)
        return instance
    }
}

extension NSObject: ActionClosurable {}
