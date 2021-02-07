//
//  ConnectionToPeer.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation
import Network

class ConnectionToPeer {
    let local: NWConnection
    let toPeer: NWConnection
    
    init(local: NWConnection, peerEndpoint: NWEndpoint, tlsOptions: NWProtocolTLS.Options?) {
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
        
        self.local.start(queue: DispatchQueue.main)
        self.toPeer.start(queue: DispatchQueue.main)
        
        let clientRequest = ClientRequest(instanceID: self.myInstanceID, instructions: config.connectInstructions)
        targetConn.send(clientRequest: clientRequest) { error in
            print("sent client request")
            guard error == nil else { return }
            conn.transcieve(between: targetConn) { error in
                print("transcieve between local and remote peer completed")
                conn.cancel()
                targetConn.cancel()
            }
        }

    }
    
    private func eitherConnectionStateChanged(_ state: NWConnection.State) {
        // If either fails or gets cancelled, ensure both are.
        switch state {
        case .waiting(_), .failed(_), .cancelled:
            if self.local.state != .cancelled {
                self.local.cancel()
            }
            if self.toPeer.state != .cancelled {
                self.toPeer.cancel()
            }
        default:
            break
        }
    }
}
