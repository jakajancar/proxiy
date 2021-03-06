//
//  ConnectionSet.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/4/21.
//

import Foundation

/// Stores connections. Maintains their `completedHandler` to remove them from self when completed. Cancels them on deinit.
class ConnectionSet<C: Connection>: ObservableObject, Sequence {
    @Published private var conns: Set<C> = []
    
    func makeIterator() -> Set<C>.Iterator {
        conns.makeIterator()
    }
    
    var count: Int {
        conns.count
    }
    
    func insert(_ conn: C) {
        precondition(conn.completedHandler == nil, "Already in another set?")
        let (inserted, _) = conns.insert(conn)
        precondition(inserted)
        conn.completedHandler = { [weak self, unowned conn] in
            guard let self = self else { return }
            self.remove(conn)
        }
    }
    
    func remove(_ conn: C) {
        precondition(conn.completedHandler != nil, "Expected completedHandler to be set")
        let removed = conns.remove(conn)
        precondition(removed != nil)
        conn.completedHandler = nil
    }
    
//    deinit {
//        for conn in conns {
//            conn.forceCancel()
//        }
//    }
}
