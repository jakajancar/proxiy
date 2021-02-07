//
//  NWConnection+Socks.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/4/21.
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "socks")

enum SocksError {
    case network(NWError)
    case proto(String)
}

extension NWConnection {
    /// Receives a SOCKS5 command on the connection and handles it.
    /// Calls completion once both sides of the stream have finished (with nil), or an error occurred.
    /// Creates an outbound connection if needed. The outbound connection will be disposed of by the time the completion is called.
    func receiveAndHandleSocks(completion: @escaping (SocksError?) -> Void) {
        self.negotiateSocksAuth { error in
            if error != nil {
                completion(error)
                return
            }
            self.receiveSocksRequestHost { (host, error) in
                if error != nil {
                    completion(error)
                    return
                }
                self.receiveSocksRequestPort { (port, error) in
                    if error != nil {
                        completion(error)
                        return
                    }
                    let target = NWEndpoint.hostPort(host: host!, port: port!)
                    self.establishOutbound(target: target) { (outbound, connectError) in
                        if let connectError = connectError {
                            assert(outbound == nil)
                            let replyCode: UInt8
                            switch connectError {
                            case .posix(let posixCode):
                                switch posixCode {
                                case .ENETUNREACH:
                                    replyCode = 3 // Network unreachable
                                case .EHOSTUNREACH, .EHOSTDOWN:
                                    replyCode = 4 // Host unreachable
                                case .ECONNREFUSED:
                                    replyCode = 5 // Connection refused
                                case .ETIMEDOUT:
                                    replyCode = 6 // TTL expired
                                default:
                                    replyCode = 1 // general SOCKS server failure
                                }
                            case .dns(_):
                                replyCode = 4 // Host unreachable (not sure if right)
                            default:
                                replyCode = 1 // general SOCKS server failure
                            }
                            self.sendSocksReply(rep: replyCode) { error in
                                if error != nil {
                                    return completion(error)
                                }

                                // Success! (although client connection did not succeed)
                                return completion(nil)
                            }
                        } else {
                            self.sendSocksReply(rep: 0) { error in
                                if error != nil {
//                                    print("cancelling outbound after error sending socks reply")
                                    outbound!.cancel()
                                    return completion(error)
                                }
//                                print("transcieving between outbound and \(self)")
                                self.transcieve(between: outbound!, completion: { error in
//                                    print("cancelling outbound after transcieve completed")
                                    outbound!.cancel()
                                    return completion(nil)
                                })
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func negotiateSocksAuth(completion: @escaping (SocksError?) -> Void) {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1) { (data, ctx, isComplete, error) in
            guard let data = data else { return completion(.network(error!)) }
            
            let version = data[0]
            if version != 5 {
                return completion(.proto("invalid socks version: \(version)"))
            }
            
            // Receive auth methods supported by client
            self.receive(minimumIncompleteLength: 1, maximumLength: 1) { (data, ctx, isComplete, error) in
                guard let data = data else { return completion(.network(error!)) }

                let numMethods = Int(data[0])
                self.receive(minimumIncompleteLength: numMethods, maximumLength: numMethods) { (data, ctx, isComplete, error) in
                    guard let data = data else { return completion(.network(error!)) }

                    // Choose 0 if possible
                    let methods = data
                    if !methods.contains(0x00) {
                        return completion(.proto("client does not support authless"))
                    }
                    
                    self.send(content: Data([0x05, 0x00]), completion: .contentProcessed({ error in
                        guard error == nil else { return completion(.network(error!)) }
                        
                        completion(nil)
                    }))
                }
            }
        }
    }

    private func receiveSocksRequestHost(completion: @escaping (NWEndpoint.Host?, SocksError?) -> Void) {
        self.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, ctx, isComplete, error) in
            guard let data = data else { return completion(nil, .network(error!)) }
            
            let version = data[0]
            let cmd = data[1]
            let atyp = data[3]
            if version != 5 {
                return completion(nil, .proto("invalid socks version: \(version)"))
            }
            if cmd != 0x01 {
                return completion(nil, .proto("invalid cmd: \(cmd)"))
            }
            switch atyp {
            case 0x01:
                // ipv4
                self.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, ctx, isComplete, error) in
                    guard let data = data else { return completion(nil, .network(error!)) }
                    
                    completion(NWEndpoint.Host.ipv4(IPv4Address(data)!), nil)
                }
            case 0x03:
                // domain
                self.receive(minimumIncompleteLength: 1, maximumLength: 1) { (data, ctx, isComplete, error) in
                    guard let data = data else { return completion(nil, .network(error!)) }
                    let len = Int(data[0])
                    
                    self.receive(minimumIncompleteLength: len, maximumLength: len) { (data, ctx, isComplete, error) in
                        guard let data = data else { return completion(nil, .network(error!)) }
                        completion(NWEndpoint.Host.name(String(data: data, encoding: .utf8)!, nil), nil)
                    }
                }

            case 0x04:
                // ipv6
                self.receive(minimumIncompleteLength: 16, maximumLength: 16) { (data, ctx, isComplete, error) in
                    guard let data = data else { return completion(nil, .network(error!)) }
                    completion(NWEndpoint.Host.ipv6(IPv6Address(data, nil)!), nil)
                }
            default:
                return completion(nil, .proto("invalid atyp: \(atyp)"))
            }
            if cmd != 0x01 {
                return completion(nil, .proto("invalid cmd: \(cmd)"))
            }

            // Choose 0 if possible
            let methods = data
            if !methods.contains(0x00) {
                return completion(nil, .proto("client does not support authless"))
            }
        }

    }
    
    private func receiveSocksRequestPort(completion: @escaping (NWEndpoint.Port?, SocksError?) -> Void) {
        self.receive(minimumIncompleteLength: 2, maximumLength: 2) { (data, ctx, isComplete, error) in
            guard let data = data else { return completion(nil, .network(error!)) }

            let port = UInt16(bigEndian: UInt16(data: data)!)
            completion(NWEndpoint.Port(rawValue: port)!, nil)
        }
    }
    
    private func sendSocksReply(rep: UInt8, completion: @escaping (SocksError?) -> Void) {
        let bytes = [
            0x05, // ver
            rep,
            0x00, // reserved
            0x01, // ipv4
            0x00, 0x00, 0x00, 0x00, // addr
            0x00, 0x00 // port
        ]
        let ctx: NWConnection.ContentContext = rep == 0 ? .defaultMessage : .finalMessage
        self.send(content: Data(bytes), contentContext: ctx, completion: .contentProcessed({ error in
            guard error == nil else { return completion(.network(error!)) }

            completion(nil)
        }))
    }
    
    private func establishOutbound(target: NWEndpoint, completion: @escaping (NWConnection?, NWError?) -> Void) {
        let targetTCPOpts = NWProtocolTCP.Options()
        targetTCPOpts.noDelay = true
        let targetParams = NWParameters.init(tls: nil, tcp: targetTCPOpts)
        
        let outbound = NWConnection(to: target, using: targetParams)
        outbound.start(queue: self.queue!)
        
        outbound.stateUpdateHandler = { [weak outbound] state in
            switch state {
            case .ready:
                completion(outbound, nil)
            case .waiting(let error), .failed(let error):
//                print("cancelling outbound after it failed to connect")
                outbound?.cancel()
                completion(nil, error)
            default:
                break
            }
        }
    }
}
