//
//  MockViewModel.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/1/21.
//

import Foundation

class MockMesh: MeshViewModel {
    typealias Peer = MockPeer
    
    var peers: Set<MockPeer>
    init(peers: Set<MockPeer> = []) {
        self.peers = peers
    }
    
    static var forDevelopment: MockMesh {
        MockMesh(peers: MockPeer.various)
    }
    
    static var forMarketing: MockMesh {
        forDevelopment
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
    
    static var various: Set<MockPeer> {
        [
            // This device
            MockPeer(deviceInfo: DeviceInfo(
                        name: "Jaka's iPhone",
                        machine: "iPhone13,1"),
                     inboundConnectionCount: 0,
                     outboundConnectionCount: 0,
                     bytesPerSec: 0),
            
            // Laptops
            MockPeer(deviceInfo: DeviceInfo(
                        name: "Jaka's MacBook Pro",
                        machine: "MacBookPro16,1"),
                     inboundConnectionCount: 33,
                     outboundConnectionCount: 0,
                     bytesPerSec: 3293291843),
            
            MockPeer(deviceInfo: DeviceInfo(
                        name: "Leah's MacBook Pro",
                        machine: "MacBookPro15,2"),
                     inboundConnectionCount: 8,
                     outboundConnectionCount: 0,
                     bytesPerSec: 23929100),

            // Tablet
            MockPeer(deviceInfo: DeviceInfo(
                        name: "Jaka's iPad Pro",
                        machine: "iPad7,1"),
                     inboundConnectionCount: 0,
                     outboundConnectionCount: 0,
                     bytesPerSec: 0),

            
            // Test for long name
            MockPeer(deviceInfo: DeviceInfo(
                        name: "A device with a very very very very very very very long name",
                        machine: "Unknown"),
                inboundConnectionCount: 1234,
                outboundConnectionCount: 9876,
                bytesPerSec: 239291000
            ),

            // Test for sorting of rows with same bw
            MockPeer(deviceInfo: DeviceInfo(name: "Device A", machine: "Unknown"), bytesPerSec: 1),
            MockPeer(deviceInfo: DeviceInfo(name: "Device D", machine: "Unknown"), bytesPerSec: 1),
            MockPeer(deviceInfo: DeviceInfo(name: "Device C", machine: "Unknown"), bytesPerSec: 1),
            MockPeer(deviceInfo: DeviceInfo(name: "Device B", machine: "Unknown"), bytesPerSec: 1),

        ]
    }
}
