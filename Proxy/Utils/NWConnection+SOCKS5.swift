//
//  ConnectionFromPeer+Socks.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/7/21.
//

import Foundation
import Network

enum SOCKS5Error: Error {
    case network(NWError)
    case proto(String)
}

enum SOCKS5Request {
    case connect(NWEndpoint.Host, NWEndpoint.Port)
//    case udpAssociate(NWEndpoint)
}

//enum SOCKS5Reply {
//
//}

/// Speaking the SOCKS5 protocol for `NWConnection`.
extension NWConnection {
    func negotiateNoAuthAndReceiveSocksRequest(completion: @escaping (Result<SOCKS5Request, SOCKS5Error>) -> Void) {
        self.negotiateNoSocksAuth { result in
            if case .failure(let error) = result {
                return completion(.failure(error))
            }
            
            self.receiveSocksRequest(completion: completion)
        }
    }
    
    /// Receive supported auth methods and pick no auth.
    func negotiateNoSocksAuth(completion: @escaping (Result<Void, SOCKS5Error>) -> Void) {
        self.receive(length: 1) { result in
            let data: Data
            switch result {
            case .success(let d): data = d
            case .failure(let error): return completion(.failure(.network(error)))
            }
            
            let version = data[0]
            if version != 5 {
                return completion(.failure(.proto("invalid socks version: \(version)")))
            }
            
            // Receive auth methods supported by client
            self.receive(length: 1) { result in
                let data: Data
                switch result {
                case .success(let d): data = d
                case .failure(let error): return completion(.failure(.network(error)))
                }

                let numMethods = Int(data[0])
                self.receive(length: numMethods) { result in
                    let data: Data
                    switch result {
                    case .success(let d): data = d
                    case .failure(let error): return completion(.failure(.network(error)))
                    }

                    // Choose 0 if possible
                    let methods = data
                    if !methods.contains(0x00) {
                        return completion(.failure(.proto("client does not support authless")))
                    }
                    
                    self.send(content: Data([0x05, 0x00]), completion: .contentProcessed({ error in
                        if let error = error {
                            return completion(.failure(.network(error)))
                        }
                        
                        completion(.success(()))
                    }))
                }
            }
        }
    }
    
    func receiveSocksRequest(completion: @escaping (Result<SOCKS5Request, SOCKS5Error>) -> Void) {
        self.receive(length: 3) { result in
            let data: Data
            switch result {
            case .success(let d): data = d
            case .failure(let error): return completion(.failure(.network(error)))
            }

            let version = data[0]
            let cmd = data[1]
            if version != 5 {
                return completion(.failure(.proto("invalid socks version: \(version)")))
            }
            if cmd != 0x01 {
                return completion(.failure(.proto("invalid cmd: \(cmd)")))
            }

            self.receiveSocksRequestHost { result in
                let host: NWEndpoint.Host
                switch result {
                case .success(let h): host = h
                case .failure(let error): return completion(.failure(error))
                }

                self.receiveSocksRequestPort { result in
                    let port: NWEndpoint.Port
                    switch result {
                    case .success(let p): port = p
                    case .failure(let error): return completion(.failure(error))
                    }
                    
                    completion(.success(.connect(host, port)))
                }
            }
        }
    }
    
    private func receiveSocksRequestHost(completion: @escaping (Result<NWEndpoint.Host, SOCKS5Error>) -> Void) {
        self.receive(length: 1) { result in
            let data: Data
            switch result {
            case .success(let d): data = d
            case .failure(let error): return completion(.failure(.network(error)))
            }

            let atyp = data[0]
            switch atyp {
            case 0x01:
                // ipv4
                self.receive(length: 4) { result in
                    let data: Data
                    switch result {
                    case .success(let d): data = d
                    case .failure(let error): return completion(.failure(.network(error)))
                    }

                    let host = NWEndpoint.Host.ipv4(IPv4Address(data)!)
                    completion(.success(host))
                }
            case 0x03:
                // domain
                self.receive(length: 1) { result in
                    let data: Data
                    switch result {
                    case .success(let d): data = d
                    case .failure(let error): return completion(.failure(.network(error)))
                    }

                    let len = Int(data[0])
                    
                    self.receive(length: len) { result in
                        let data: Data
                        switch result {
                        case .success(let d): data = d
                        case .failure(let error): return completion(.failure(.network(error)))
                        }
                        
                        let host = NWEndpoint.Host.name(String(data: data, encoding: .utf8)!, nil)
                        completion(.success(host))
                    }
                }

            case 0x04:
                // ipv6
                self.receive(length: 16) { result in
                    let data: Data
                    switch result {
                    case .success(let d): data = d
                    case .failure(let error): return completion(.failure(.network(error)))
                    }

                    let host = NWEndpoint.Host.ipv6(IPv6Address(data, nil)!)
                    completion(.success(host))
                }
            default:
                return completion(.failure(.proto("invalid atyp: \(atyp)")))
            }
        }

    }
    
    private func receiveSocksRequestPort(completion: @escaping (Result<NWEndpoint.Port, SOCKS5Error>) -> Void) {
        self.receive(length: 2) { result in
            let data: Data
            switch result {
            case .success(let d): data = d
            case .failure(let error): return completion(.failure(.network(error)))
            }

            let port = UInt16(bigEndian: UInt16(data: data)!)
            completion(.success(NWEndpoint.Port(rawValue: port)!))
        }
    }
    
    private func sendSocksReply(code: UInt8, completion: @escaping (Result<Void, NWError>) -> Void) {
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
            if let error = error {
                return completion(.failure(error))
            }

            completion(.success(()))
        }))
    }
    
    func sendSocksErrorReplyAndClose(codeForError error: NWError, completion: @escaping (Result<Void, NWError>) -> Void) {
        sendSocksReply(code: socks5ReplyCode(for: error), completion: completion)
    }
    
    func sendSocksSuccessReply(completion: @escaping (Result<Void, NWError>) -> Void) {
        sendSocksReply(code: 0, completion: completion)
    }
}

private func socks5ReplyCode(for error: NWError) -> UInt8 {
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
