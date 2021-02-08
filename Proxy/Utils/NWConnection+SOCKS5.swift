//
//  ConnectionFromPeer+Socks.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation
import Network

enum SOCKS5Error {
    case network(NWError)
    case proto(String)
}

enum SOCKS5Request {
    case connect(NWEndpoint)
//    case udpAssociate(NWEndpoint)
}

//enum SOCKS5Reply {
//
//}

/// Speaking the SOCKS5 protocol for `NWConnection`.
extension NWConnection {
    /// Receive supported auth methods and pick no auth.
    func negotiateNoSocksAuth(completion: @escaping (SOCKS5Error?) -> Void) {
        self.receive(length: 1) { (data, error) in
            guard let data = data else { return completion(.network(error!)) }
            
            let version = data[0]
            if version != 5 {
                return completion(.proto("invalid socks version: \(version)"))
            }
            
            // Receive auth methods supported by client
            self.receive(length: 1) { (data, error) in
                guard let data = data else { return completion(.network(error!)) }

                let numMethods = Int(data[0])
                self.receive(length: numMethods) { (data, error) in
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
    
    func receiveSocksRequest(completion: @escaping (SOCKS5Request?, SOCKS5Error?) -> Void) {
        self.receive(length: 3) { (data, error) in
            guard let data = data else { return completion(nil, .network(error!)) }
            
            let version = data[0]
            let cmd = data[1]
            if version != 5 {
                return completion(nil, .proto("invalid socks version: \(version)"))
            }
            if cmd != 0x01 {
                return completion(nil, .proto("invalid cmd: \(cmd)"))
            }

            self.receiveSocksRequestHost { (host, error) in
                guard let host = host else { return completion(nil, error!) }
                self.receiveSocksRequestPort { (port, error) in
                    guard let port = port else { return completion(nil, error!) }
                    let endpoint = NWEndpoint.hostPort(host: host, port: port)
                    completion(.connect(endpoint), nil)
                }
            }
        }
    }
    
    private func receiveSocksRequestHost(completion: @escaping (NWEndpoint.Host?, SOCKS5Error?) -> Void) {
        self.receive(length: 1) { (data, error) in
            guard let data = data else { return completion(nil, .network(error!)) }

            let atyp = data[0]
            switch atyp {
            case 0x01:
                // ipv4
                self.receive(length: 4) { (data, error) in
                    guard let data = data else { return completion(nil, .network(error!)) }

                    completion(NWEndpoint.Host.ipv4(IPv4Address(data)!), nil)
                }
            case 0x03:
                // domain
                self.receive(length: 1) { (data, error) in
                    guard let data = data else { return completion(nil, .network(error!)) }
                    
                    let len = Int(data[0])
                    
                    self.receive(minimumIncompleteLength: len, maximumLength: len) { (data, ctx, isComplete, error) in
                        guard let data = data else { return completion(nil, .network(error!)) }
                        completion(NWEndpoint.Host.name(String(data: data, encoding: .utf8)!, nil), nil)
                    }
                }

            case 0x04:
                // ipv6
                self.receive(length: 16) { (data, error) in
                    guard let data = data else { return completion(nil, .network(error!)) }
                    
                    completion(NWEndpoint.Host.ipv6(IPv6Address(data, nil)!), nil)
                }
            default:
                return completion(nil, .proto("invalid atyp: \(atyp)"))
            }
        }

    }
    
    private func receiveSocksRequestPort(completion: @escaping (NWEndpoint.Port?, SOCKS5Error?) -> Void) {
        self.receive(length: 2) { (data, error) in
            guard let data = data else { return completion(nil, .network(error!)) }

            let port = UInt16(bigEndian: UInt16(data: data)!)
            completion(NWEndpoint.Port(rawValue: port)!, nil)
        }
    }
    
    func sendSocksReply(code: UInt8, completion: @escaping (SOCKS5Error?) -> Void) {
//        print("\(self) sending socks reply \(code)")
        let bytes = [
            0x05, // ver
            code,
            0x00, // reserved
            0x01, // ipv4
            0x00, 0x00, 0x00, 0x00, // addr
            0x00, 0x00 // port
        ]
        let ctx: NWConnection.ContentContext = code == 0 ? .defaultMessage : .finalMessage
        self.send(content: Data(bytes), contentContext: ctx, completion: .contentProcessed({ error in
//            print("\(self) socks reply send returned with err \(error)")
            guard error == nil else { return completion(.network(error!)) }

            completion(nil)
            
            // TODO: explicitly cancel here for TLS?
        }))
    }
}

func socks5ReplyCode(for error: NWError) -> UInt8 {
    switch error {
    case .posix(let posixCode):
        switch posixCode {
        case .ENETUNREACH:
            return 3 // Network unreachable
        case .EHOSTUNREACH, .EHOSTDOWN:
            return 4 // Host unreachable
        case .ECONNREFUSED:
            return 5 // Connection refused
        case .ETIMEDOUT:
            return 6 // TTL expired
        default:
            return 1 // general SOCKS server failure
        }
    case .dns(_):
        return 4 // Host unreachable (not sure if right)
    default:
        return 1 // general SOCKS server failure
    }
}
