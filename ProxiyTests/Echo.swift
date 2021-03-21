//
//  Echo.swift
//  ProxyTests
//
//  Created by Jaka Jancar on 3/2/21.
//

import Foundation
import Network
@testable import Proxiy

func createEchoListener(params: NWParameters, completion: @escaping (NWListener, NWEndpoint) -> Void) {
    let listener = try! NWListener(using: params)
    listener.newConnectionHandler = { conn in
        conn.start(queue: DispatchQueue.main)
        conn.forwardAllMessages(to: conn) { srcCtx in
            NWConnection.ContentContext(identifier: "echo", isFinal: srcCtx.isFinal)
        } completion: { result in
            if case .failure(let error) = result {
                fatalError("Echo forward failed: \(error)")
            }
        }
    }
    listener.stateUpdateHandler = { state in
        switch state {
        case .failed(let error):
            fatalError("Echo listener failed: \(error)")
        case .ready:
            // Listener ready, create connection to it
            let listenerEndpoint = NWEndpoint.hostPort(host: .name("localhost", nil), port: listener.port!)
            completion(listener, listenerEndpoint)
        default:
            break
        }
    }
    listener.start(queue: DispatchQueue.main)
}

/// Creates a TCP/UDP connection that echoes back stuff sent to it. Uses `NWConnection.forwardAllMessages`
func createEchoConnection(params: NWParameters, completion: @escaping (NWConnection) -> Void) {
    createEchoListener(params: params) { (listener, listenerEndpoint) in
        let client = NWConnection(to: listenerEndpoint, using: params)
        client.stateUpdateHandler = { status in
            switch status {
            case .ready:
                completion(client)
            case .failed(_):
                // the dual connect aborted connection also fails here
                break
            default:
                break
            }
        }
        client.start(queue: DispatchQueue.main)
    }
}

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
        let packets = 10*1000 // 10MB
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
}
