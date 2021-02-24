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
    var acceptsInbound: Bool { get }
    var connectionsFromCount: Int { get }
    var connectionsToCount: Int { get }
    var bytesPerSec: Int64 { get }
}
