//
//  Hashable.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation

extension Equatable where Self: AnyObject {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs === rhs
    }
}

extension Hashable where Self: AnyObject {
    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}
