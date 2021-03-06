//
//  ConnectionToPeer.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "forpeer")

class ConnectionForPeer: Connection {
    private let myInstanceID: InstanceID
    private let listenerConfig: Config.Listener
    private let local: NWConnection
    
    private var queue: DispatchQueue?
    private var toPeer: NWConnection?
    private var completed: Bool = false
    
    /// Called at most once. If peer is matched returns a connection, otherwise nil.
    var connectPeer: ((Config.Via) -> NWConnection?)?

    /// Called exactly once.
    var completedHandler: (() -> Void)?
    
    init(myInstanceID: InstanceID, listenerConfig: Config.Listener, local: NWConnection) {
        self.myInstanceID = myInstanceID
        self.listenerConfig = listenerConfig
        self.local = local
    }
    
    func start(queue: DispatchQueue) {
        self.queue = queue
        self.local.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
        self.local.start(queue: queue)

        switch listenerConfig {
        case .tcp(_, _, let endpoint), .udp(_, _, let endpoint):
            let connectInstructions: PeerRequest.ConnectInstructions
            switch listenerConfig {
            case .tcp(_, _, _): connectInstructions = .tcp(endpoint)
            case .udp(_, _, _): connectInstructions = .udp(endpoint)
            default: fatalError()
            }
            
            let peerRequest = PeerRequest(instanceID: self.myInstanceID, instructions: connectInstructions)
            self.startPeerConnection(request: peerRequest) { result in
                switch result {
                case .failure(_):
                    self.forceCancel()
                case .success(let peerResponse):
                    if let remoteError = peerResponse.error {
                        logger.log("Remote connect error: \(String(describing: remoteError))")
                        self.forceCancel()
                    } else {
                        self.toPeer!.connectTunnel(toRaw: self.local) { result in
                            switch result {
                            case .success():
                                // connection gracefully finished in both directions
//                                logger.log("Local<->Peer raw connection gracefully finished")
                                break
                            case .failure(_):
                                self.forceCancel()
                            }
                        }
                    }
                }
            }

        case .socks(_, _):
            self.local.negotiateNoAuthAndReceiveSocksRequest { result in
                switch result {
                case .failure(.proto(let error)):
                    logger.log("SOCKS5 error receiving request: \(error)")
                    self.forceCancel()
                case .failure(_):
                    self.forceCancel()
                case .success(.connect(let host, let port)):
                    let peerRequest = PeerRequest(
                        instanceID: self.myInstanceID,
                        instructions: .tcp(.init(nwHost: host, port: port))
                    )
                    
                    self.startPeerConnection(request: peerRequest) { result in
                        switch result {
                        case .failure(_):
                            self.forceCancel()
                        case .success(let peerResponse):
                            if let remoteError = peerResponse.error {
                                logger.log("Remote connect error: \(String(describing: remoteError))")
                                self.toPeer!.sendSocksErrorReplyAndClose(codeForError: remoteError) { result in
                                    self.forceCancel()
                                }
                            } else {
                                self.local.sendSocksSuccessReply { result in
                                    switch result {
                                    case .failure(_):
                                        self.forceCancel()
                                    case .success():
                                        self.toPeer!.connectTunnel(toRaw: self.local) { result in
                                            switch result {
                                            case .success():
                                                // connection gracefully finished in both directions
//                                                logger.log("Local<->Peer SOCKS connection gracefully finished")
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
            }
        }
    }
        
    private func startPeerConnection(request: PeerRequest, completion: @escaping (Result<PeerResponse, NWError>) -> Void) {
        guard let toPeer = self.connectPeer!(self.listenerConfig.via) else { return self.forceCancel() }
        self.toPeer = toPeer
        toPeer.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
        toPeer.start(queue: self.queue!)
        
        toPeer.send(peerMessage: request) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success():
                toPeer.receivePeerMessage { (result: Result<PeerResponse, NWError>) in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let response):
                        completion(.success(response))
                    }
                }
            }
        }
    }
    
    func forceCancel() {
        if !self.completed {
            self.completed = true
            
            if self.local.state != .cancelled {
                self.local.forceCancel()
            }
            
            if let toPeer = self.toPeer, toPeer.state != .cancelled {
                toPeer.forceCancel()
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
