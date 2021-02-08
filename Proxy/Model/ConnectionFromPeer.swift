//
//  ConnectionFromPeer.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "frompeer")

class ConnectionFromPeer: Equatable, Hashable {
    private let fromPeer: NWConnection
    private var outbound: NWConnection?
    
    private var queue: DispatchQueue?
    var peerInstanceID: InstanceID?
    private var completed: Bool = false

    /// Called at most once.
    var identifiedHandler: (() -> Void)?

    /// Called exactly once.
    var completedHandler: (() -> Void)?
    
    init(_ fromPeer: NWConnection) {
        self.fromPeer = fromPeer
        self.fromPeer.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
        
        self.fromPeer.receivePeerHello { (clientRequest, error) in
            guard error == nil else { return self.forceCancel() }
            guard let clientRequest = clientRequest else { return self.forceCancel() }
            
            self.peerInstanceID = clientRequest.instanceID
            self.identifiedHandler!()
            
            self.receiveAndHandleSocks { error in
                if let error = error {
                    if case .proto(let str) = error {
                        logger.log("SOCKS protocol error: \(str)")
                    }
                    self.forceCancel()
                }
            }
        }

    }
    
    func start(queue: DispatchQueue) {
        self.queue = queue
        self.fromPeer.start(queue: queue)
    }
    
    func forceCancel() {
        if !self.completed {
//            print("forceCancel called on \(self.fromPeer)")
            self.completed = true
            
            if self.fromPeer.state != .cancelled {
                self.fromPeer.forceCancel()
            }
            
            if self.outbound?.state != .cancelled {
                self.outbound?.forceCancel()
            }
            
            if let handler = self.completedHandler {
                handler()
            }
        }
    }
    
    private func eitherConnectionStateChanged(_ state: NWConnection.State) {
        switch state {
        case .waiting(_), .failed(_), .cancelled:
            self.forceCancel()
        default:
            break
        }
    }
    
    private func receiveAndHandleSocks(completion: @escaping (SOCKS5Error?) -> Void) {
        self.fromPeer.negotiateNoSocksAuth { error in
            guard error == nil else { return completion(error!) }
            
            self.fromPeer.receiveSocksRequest { (request, error) in
                guard let request = request else { return completion(error!) }
                
                switch request {
                case .connect(let endpoint):
                    self.establishOutbound(to: endpoint) { error in
                        if let error = error {
                            // Connect failed
                            let replyCode = socks5ReplyCode(for: error)
                            self.fromPeer.sendSocksReply(code: replyCode) { error in
                                guard error == nil else { return completion(error!) }
                                // sendSocksReply will also send EOF, which will hopefully lead to shutdown
                            }
                        } else {
                            // Connect succeeded
                            self.fromPeer.sendSocksReply(code: 0) { error in
                                guard error == nil else { return completion(error!) }
                                
//                                print("transcieving between outbound and \(self)")
                                self.fromPeer.transcieve(between: self.outbound!, completion: { error in
//                                    print("transcieve completed with error \(error)")
                                    if let error = error {
                                        completion(.network(error))
                                    } else {
                                        completion(nil)
                                    }
                                })
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Establishes the outbound connections. Intercepts the initial .ready or .waiting/.failure status and returns it in the closure,
    /// afterwards sets handler to `self.eitherConnectionStateChanged`.
    private func establishOutbound(to endpoint: NWEndpoint, completion: @escaping (NWError?) -> Void) {
        assert(self.outbound == nil)
        
        let tcpOpts = NWProtocolTCP.Options()
        tcpOpts.noDelay = true
        let params = NWParameters.init(tls: nil, tcp: tcpOpts)
        
        let outbound = NWConnection(to: endpoint, using: params)
        self.outbound = outbound // set immediately so forceCancel works, but don't set handler yet.
        outbound.stateUpdateHandler = { state in
            switch state {
            case .waiting(let error), .failed(let error):
                outbound.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
                completion(error)
            case .ready:
                outbound.stateUpdateHandler = self.eitherConnectionStateChanged(_:)
                completion(nil)
            default:
                break
            }
        }
        outbound.start(queue: self.queue!)
    }
}
