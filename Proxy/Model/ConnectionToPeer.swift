//
//  ConnectionToPeer.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "topeer")

class ConnectionToPeer: Equatable, Hashable {
    private let local: NWConnection
    private let toPeer: NWConnection
    private var queue: DispatchQueue?
    private var completed: Bool = false
    
    /// Called exactly once.
    var completedHandler: (() -> Void)?
    
    init(local: NWConnection, peerEndpoint: NWEndpoint, tlsOptions: NWProtocolTLS.Options?, myInstanceID: InstanceID) {
        let targetTCPOpts = NWProtocolTCP.Options()
        targetTCPOpts.noDelay = true
        
        self.local = local
        self.toPeer = NWConnection(
            to: peerEndpoint,
            using: NWParameters.init(
                tls: tlsOptions,
                tcp: targetTCPOpts
            )
        )
        
        self.local.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
        self.toPeer.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
        
        
        let clientRequest = PeerHello(instanceID: myInstanceID)
        self.toPeer.send(peerHello: clientRequest) { error in
//            print("sent client request")
            guard error == nil else { return self.forceCancel() }
            self.local.transcieve(between: self.toPeer) { error in
//                print("transcieve between local and remote peer completed")
//                self.local.cancel()
//                self.toPeer.cancel()
            }
        }

    }
    
    func start(queue: DispatchQueue) {
        self.queue = queue
        self.local.start(queue: queue)
        self.toPeer.start(queue: queue)
    }
    
    func forceCancel() {
        if !self.completed {
            self.completed = true
            
            if self.local.state != .cancelled {
                self.local.forceCancel()
            }
            
            if self.toPeer.state != .cancelled {
                self.toPeer.forceCancel()
            }
            
            if let handler = self.completedHandler {
                handler()
            }
        }
    }
    
    private func eitherConnectionStateChanged(_ state: NWConnection.State) {
        // If either fails or gets cancelled, ensure both are.
        switch state {
        case .waiting(_), .failed(_), .cancelled:
            self.forceCancel()
        default:
            break
        }
    }
}
