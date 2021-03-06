//
//  Messages.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/1/21.
//

import Foundation
import Network

/// Extensions for the WebSocket-based connection to peer.
extension NWConnection {
    // MARK: Sending and receiving tunnel control messages (WS text)
    
    func send<M: Codable>(peerMessage: M, completion: @escaping (Result<Void, NWError>) -> Void) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "textContext", metadata: [metadata])
        let content = try! JSONEncoder().encode(peerMessage)

        self.send(content: content, contentContext: context, completion: .contentProcessed({ error in
            if let error = error {
                return completion(.failure(error))
            }
            completion(.success(()))
        }))
    }

    func receivePeerMessage<M: Codable>(completion: @escaping (Result<M, NWError>) -> Void) {
        self.receiveMessage { (data, context, isComplete, error) in
            if let error = error {
                return completion(.failure(error))
            }
            guard let context = context, let metadata = context.wsMetadata, metadata.opcode != .close, let data = data else {
                return completion(.failure(.posix(.ENODATA)))
            }
            guard metadata.opcode == .text else {
                fatalError("Unexpected opcode: \(metadata.opcode)")
            }
            let hello = try! JSONDecoder().decode(M.self, from: data)
            return completion(.success(hello))
        }
    }
    
    // MARK: Sending and receiving tunneled data (WS binary)
    
    func connectTunnel(
        toRaw raw: NWConnection,
        completion: @escaping (Result<Void, NWError>) -> Void)
    {
        let expectedRawIsFinal: Bool
        switch raw.parameters.defaultProtocolStack.transportProtocol {
        case is NWProtocolTCP.Options: expectedRawIsFinal = true  // only a single message in connection
        case is NWProtocolUDP.Options: expectedRawIsFinal = false // connectionless, no concept of closing
        default:
            fatalError("Unknown transport protocol")
        }
        
        NWConnection.forwardMessageBetween(
            a: raw,
            b: self,
            mappingContextFromA: { rawCtx -> NWConnection.ContentContext in
                // Forward from `raw` to tunnel (`self`), encapsulating into binary messages.
//                print("mapping from raw to tunnel")
                precondition(rawCtx.isFinal == expectedRawIsFinal)
                return NWConnection.ContentContext(
                    identifier: "encapsulated",
                    isFinal: false, // WS would fail, expects isFinal only on .close, plus closes both sides
                    metadata: [
                        NWProtocolWebSocket.Metadata(opcode: .binary),
                    ]
                )
            },
            mappingContextFromB: { wsCtx -> NWConnection.ContentContext in
                // Forward tunnel (`self`) to `raw`, unwrapping binary messages.
//                print("mapping from tunnel to raw")
                let opcode = wsCtx.wsMetadata?.opcode
                precondition(opcode == .binary, "Expected binary message, got \(String(describing: opcode))")
                return NWConnection.ContentContext(
                    identifier: "raw",
                    isFinal: expectedRawIsFinal
                )
            }
        ) { result in
            switch result {
            case .success():
                // Send close. This can only be done after both sides are done, since WebSocket does not allow half-closed connections.
                self.send(
                    content: nil,
                    contentContext: .finalMessage,
                    completion: .contentProcessed({ error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    })
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

private extension NWConnection.ContentContext {
    var wsMetadata: NWProtocolWebSocket.Metadata? {
        self.protocolMetadata.first as? NWProtocolWebSocket.Metadata
    }
}
