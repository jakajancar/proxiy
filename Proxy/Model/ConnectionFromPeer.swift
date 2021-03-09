//
//  ConnectionFromPeer.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxiy", category: "frompeer")

/// Should be created before `fromPeer` is started, to ensure `completedHandler` is called.
class ConnectionFromPeer: Connection {
    private let fromPeer: NWConnection
    
    private var queue: DispatchQueue?
    private var outbound: NWConnection?
    private var completed: Bool = false

    /// Called at most once. If instanceID is valid returns true, otherwise false
    var identifiedHandler: ((InstanceID) -> Bool)?

    /// Called exactly once.
    var completedHandler: (() -> Void)?
    
    init(_ fromPeer: NWConnection) {
        self.fromPeer = fromPeer
    }
    
    func start(queue: DispatchQueue) {
        self.queue = queue
        self.fromPeer.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
        self.fromPeer.start(queue: queue)
        
        self.fromPeer.receivePeerMessage { (result: Result<PeerRequest, NWError>) in
            switch result {
            case .failure(_):
                self.forceCancel()
            case .success(let peerRequest):
                guard self.identifiedHandler!(peerRequest.instanceID) else {
                    // Unknown peer
                    return self.forceCancel()
                }
                
                self.establishOutbound(peerRequest.instructions) { result in
                    switch result {
                    case .failure(let error):
                        self.fromPeer.send(peerMessage: PeerResponse(error: error)) { result in
                            self.fromPeer.cancel() // close nicely
                        }
                    case .success():
                        self.fromPeer.send(peerMessage: PeerResponse(error: nil)) { result in
                            self.fromPeer.connectTunnel(toRaw: self.outbound!) { result in
                                switch result {
                                case .success():
                                    // connection gracefully finished in both directions
//                                    logger.log("Peer<->Outbound connection gracefully finished")
                                    break
                                case .failure(_):
                                    self.forceCancel()
                                }
                            }
                        }
                    }
                }
            }
        }

    }
    
    /// Establishes the outbound connection. Intercepts the initial .ready or .waiting/.failure status and returns it in the closure,
    /// afterwards sets handler to `self.eitherConnectionStateChanged`.
    private func establishOutbound(_ instructions: PeerRequest.ConnectInstructions, completion: @escaping (Result<Void, NWError>) -> Void) {
        precondition(self.outbound == nil)

        let params: NWParameters
        switch instructions {
        case .tcp(_):
            let tcpOpts = NWProtocolTCP.Options()
            tcpOpts.noDelay = true
            params = NWParameters(tls: nil, tcp: tcpOpts)
        case .udp(_):
            params = NWParameters.udp
        }
        
        let outbound = NWConnection(to: instructions.target.nw, using: params)
        self.outbound = outbound // set immediately so forceCancel works, but don't set handler yet.
        outbound.stateUpdateHandler = { state in
            switch state {
            case .waiting(let error), .failed(let error):
                outbound.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
                completion(.failure(error))
            case .ready:
                outbound.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
                completion(.success(()))
            default:
                break
            }
        }
        outbound.start(queue: self.queue!)
    }
    
    func forceCancel() {
        if !self.completed {
            self.completed = true
            
            if self.fromPeer.state != .cancelled {
                self.fromPeer.forceCancel()
            }
            
            if let outbound = self.outbound, outbound.state != .cancelled {
                outbound.forceCancel()
            }
            
            if let handler = self.completedHandler {
                handler()
            }
        }
    }
    
    private func eitherConnectionStateChanged(_ state: NWConnection.State) {
        // If either fails or gets cancelled, ensure both are cancelled.
        switch state {
        case .waiting(_), .failed(_), .cancelled:
            self.forceCancel()
        default:
            break
        }
    }
}
