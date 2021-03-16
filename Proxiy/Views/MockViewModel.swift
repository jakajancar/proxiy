//
//  MockViewModel.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/1/21.
//

import Foundation

class MockMesh: MeshViewModel {
    typealias Peer = MockPeer
    
    var status: MeshStatus
    var peers: Set<MockPeer>
    
    init(status: MeshStatus = .connected, peers: Set<MockPeer> = []) {
        self.status = status
        self.peers = peers
    }    
}

class MockPeer: PeerViewModel {
    var isMe: Bool
    var deviceInfo: DeviceInfo
    var acceptsInbound: Bool
    var connectionsFromCount: Int
    var connectionsToCount: Int
    var bytesPerSec: UInt64

    init(
        isMe: Bool = false,
        deviceInfo: DeviceInfo = DeviceInfo(name: "Unknown device", machine: "Unknown"),
        acceptsInbound: Bool = true,
        inboundConnectionCount: Int = 0,
        outboundConnectionCount: Int = 0,
        bytesPerSec: UInt64 = 0
    ) {
        self.isMe = isMe
        self.deviceInfo = deviceInfo
        self.acceptsInbound = acceptsInbound
        self.connectionsFromCount = inboundConnectionCount
        self.connectionsToCount = outboundConnectionCount
        self.bytesPerSec = bytesPerSec
    }    
}
