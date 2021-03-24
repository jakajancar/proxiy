//
//  NWConnection+Testing.swift
//  ProxiyTests
//
//  Created by Jaka Jancar on 3/24/21.
//

import Foundation
import Network
@testable import Proxiy

extension NWConnection {
    func startAndAwaitReady(completion: @escaping () -> Void) {
        self.stateUpdateHandler = { status in
            switch status {
            case .ready:
                completion()
            case .failed(_):
                // the dual connect aborted connection also fails here
                break
            default:
                break
            }
        }
        self.start(queue: DispatchQueue.main)
    }
    
    func sendAndExpectBytes(_ string: String, completion: @escaping () -> Void) {
        let data = string.data(using: .utf8)!
        self.send(content: data, isComplete: true, completion: .contentProcessed({ error in
            switch self.parameters.defaultProtocolStack.transportProtocol {
            case is NWProtocolTCP.Options:
                self.receive(length: data.count) { result in
                    switch result {
                    case .success(let receivedData):
                        precondition(receivedData == data)
                        completion()
                    case .failure(let error):
                        fatalError("Did not receive bytes back: \(error)")
                    }
                }
            case is NWProtocolUDP.Options:
                self.receiveMessage { (receivedData, ctx, isComplete, error) in
                    precondition(error == nil)
                    precondition(receivedData == data)
                    precondition(ctx?.isFinal == false)
                    precondition(isComplete)
                    completion()
                }
            default:
                fatalError("Unknown transport protocol")
            }
        }))
    }
    
    // Not pipelined.
    func benchmarkSendAndReceive(completion: @escaping () -> Void) {
        let content = String(repeating: "x", count: 1000)
        let packets = 1*1000 // 10MB
        var remaining = packets
        let start = Date()
        
        var iterate: (() -> Void)!
        iterate = {
            if remaining > 0 {
                remaining -= 1
                self.sendAndExpectBytes(content) {
                    iterate()
                }
            } else {
                let duration = start.distance(to: Date())
                let bytesPerSec = Double(packets) * Double(content.count) / duration
                print("\(bytesPerSec*8/1e6) Mbit/s")
                completion()
            }
        }
        
        iterate()
    }
    
    // Benchmark establishment
    static func benchmarkEstablishment(endpoint: NWEndpoint, params: NWParameters, completion: @escaping () -> Void) {
        let connections = 100
        var remaining = connections
        let start = Date()
        
        var iterate: (() -> Void)!
        iterate = {
            if remaining > 0 {
                remaining -= 1
                let conn = NWConnection(to: endpoint, using: params)
                conn.startAndAwaitReady {
                    conn.cancel()
                    iterate()
                }
            } else {
                let duration = start.distance(to: Date())
                let connsPerSec = Double(connections) / duration
                print("\(connsPerSec) conns/s")
                completion()
            }
        }
        
        iterate()
    }
}
