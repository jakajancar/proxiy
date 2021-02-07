//
//  MockViewModel.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/1/21.
//

import Foundation

class MockMesh: MeshViewModel {
    typealias Peer = MockPeer
    
    var config: Config
    var peers: Set<MockPeer>
    init(peers: Set<MockPeer> = []) {
        self.config = Config(psk: "test", allowInbound: true, listeners: [])
        self.peers = peers
    }
}

class MockPeer: PeerViewModel {
    var deviceInfo: DeviceInfo
    var connectionsFromCount: Int
    var connectionsToCount: Int
    var bytesPerSec: Int64

    init(
        deviceInfo: DeviceInfo = DeviceInfo(name: "Unknown device", machine: "Unknown"),
        inboundConnectionCount: Int = 0,
        outboundConnectionCount: Int = 0,
        bytesPerSec: Int64 = 0
    ) {
        self.deviceInfo = deviceInfo
        self.connectionsFromCount = inboundConnectionCount
        self.connectionsToCount = outboundConnectionCount
        self.bytesPerSec = bytesPerSec
    }
}
