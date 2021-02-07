//
//  ViewModel.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/31/21.
//

import Foundation
import Network

protocol MeshViewModel: ObservableObject {
    associatedtype Peer: PeerViewModel
    var peers: Set<Peer> { get }
}

protocol PeerViewModel: ObservableObject, Hashable, Identifiable {
    var deviceInfo: DeviceInfo { get }
    var connectionsFromCount: Int { get }
    var connectionsToCount: Int { get }
    var bytesPerSec: Int64 { get }

}

extension PeerViewModel {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        self.id.hash(into: &hasher)
    }
}
