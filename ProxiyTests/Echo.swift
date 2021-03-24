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
