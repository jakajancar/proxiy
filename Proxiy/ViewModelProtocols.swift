//
//  ViewModel.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/31/21.
//

import Foundation
import Network

enum MeshStatus: Equatable {
    case starting
    case searching
    case connected
    case noLocalNetworkPermission
    case errors([String])
}

protocol MeshViewModel: ObservableObject {
    associatedtype Peer: PeerViewModel
    var status: MeshStatus { get }
    var peers: Set<Peer> { get }
}

protocol PeerViewModel: ObservableObject, Hashable, Identifiable {
    var isMe: Bool { get }
    var deviceInfo: DeviceInfo { get }
    var acceptsInbound: Bool { get }
    var connectionsFromCount: Int { get }
    var connectionsToCount: Int { get }
    var bytesPerSec: UInt64 { get }
}
