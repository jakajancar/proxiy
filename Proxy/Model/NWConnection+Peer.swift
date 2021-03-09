//
//  Messages.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/1/21.
//

import Foundation
import Network

private typealias DebugPrint = (String) -> Void
private typealias PumpCompletion = (Result<Void, NWError>) -> Void

/// Extensions for the WebSocket-based connection to peer.
extension NWConnection {
    // MARK: Sending and receiving tunnel control messages (WS text)
    
    func send<M: Codable>(peerMessage: M, completion: @escaping (Result<Void, NWError>) -> Void) {
        let context = ContentContext.wsText("control")
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
    
    // If completion is called with `.success`, both `self` and `raw` are finished.
    func connectTunnel(
        debugIdentifier: String,
        toRaw raw: NWConnection,
        completion: @escaping (Result<Void, NWError>) -> Void)
    {
//        let debugPrint = { (msg: String) in print("\(debugIdentifier): \(msg)") }
        let debugPrint = { (msg: String) in }
        
        enum Status {
            case bothOpen
            case oneSideCleanlyClosed
            case oneSideFailed
        }

        var status = Status.bothOpen
        let wrappedCompletion: PumpCompletion = { result in
            switch (status, result) {
            case (.bothOpen, .success(())):
                status = .oneSideCleanlyClosed
            case (.bothOpen, .failure(let error)):
                debugPrint("first side failed: \(error)")
                status = .oneSideFailed
                completion(.failure(error)) // fail immediately so pipe gets shut down eagerly
            case (.oneSideCleanlyClosed, .success(())):
                debugPrint("both sides finished cleanly")
                completion(.success(()))
            case (.oneSideCleanlyClosed, .failure(let error)):
                debugPrint("second side failed: \(error)")
                completion(.failure(error))
            case (.oneSideFailed, _):
                break // already sent
            }
        }
        
        switch raw.parameters.defaultProtocolStack.transportProtocol {
        case is NWProtocolTCP.Options:
            // 1 WS binary message == entire TCP connection
            let wsCtx = ContentContext.wsBinary("wstcp")
            self.pumpFromTCP(debugPrint: debugPrint, raw: raw, wsCtx: wsCtx, completion: wrappedCompletion)
            self.pumpToTCP(debugPrint: debugPrint, raw: raw, completion: wrappedCompletion)

        case is NWProtocolUDP.Options:
            // 1 WS binary message == 1 UDP datagram
            self.pumpFromUDP(debugPrint: debugPrint, raw: raw, completion: wrappedCompletion)
            self.pumpToUDP(debugPrint: debugPrint, raw: raw, completion: wrappedCompletion)
            
        default:
            fatalError("Unknown transport protocol")
        }
    }
    
    private func pumpFromTCP(debugPrint: @escaping DebugPrint, raw: NWConnection, wsCtx: ContentContext, completion: @escaping PumpCompletion) {
        raw.receive(minimumIncompleteLength: 1, maximumLength: Int.max) { (data, ctx, isComplete, error) in
            switch (data, ctx, isComplete, error) {
            case (_, _, _, .some(let error)):
                debugPrint("TCP->WS receive error: \(error)")
                return completion(.failure(error))
            case (let data, .some(let ctx), let isComplete, .none) where ctx.isFinal /* always for TCP */:
                debugPrint("TCP->WS received \(String(describing: data)), isComplete = \(isComplete)")
                self.send(content: data, contentContext: wsCtx, isComplete: isComplete, completion: .contentProcessed({ error in
                    if let error = error {
                        debugPrint("TCP->WS send error: \(error)")
                        return completion(.failure(error))
                    }
                    if isComplete {
                        return completion(.success(()))
                    } else {
                        return self.pumpFromTCP(debugPrint: debugPrint, raw: raw, wsCtx: wsCtx, completion: completion)
                    }
                }))
            case (let data, let ctx, let isComplete, let error):
                fatalError("Unexpected callback pumping TCP>WS: " + Self.callbackDesription(data: data, ctx: ctx, isComplete: isComplete, error: error))
            }
        }
    }
    
    private func pumpToTCP(debugPrint: @escaping DebugPrint, raw: NWConnection, completion: @escaping PumpCompletion) {
        self.receive(minimumIncompleteLength: 1, maximumLength: Int.max) { (data, ctx, isComplete, error) in
            switch (data, ctx, isComplete, error) {
            case (_, _, _, .some(let error)):
                return completion(.failure(error))
            case (nil, .some(let ctx), true, .none) where ctx.isFinal:
                debugPrint("WS->TCP terminated uncleanly")
                return completion(.failure(.posix(.ENODATA)))
            case (let data, .some(let ctx), isComplete, .none) where !ctx.isFinal && ctx.wsMetadata?.opcode == .binary:
                debugPrint("WS->TCP received \(String(describing: data)), isComplete = \(isComplete)")
                let tcpCtx: ContentContext = isComplete ? .finalMessage : .defaultMessage
                raw.send(content: data, contentContext: tcpCtx, completion: .contentProcessed({ error in
                    if let error = error {
                        return completion(.failure(error))
                    }
                    if isComplete {
                        return completion(.success(()))
                    } else {
                        return self.pumpToTCP(debugPrint: debugPrint, raw: raw, completion: completion)
                    }
                }))
            case (let data, let ctx, let isComplete, let error):
                fatalError("Unexpected callback pumping WS>TCP: " + Self.callbackDesription(data: data, ctx: ctx, isComplete: isComplete, error: error))
            }
        }
    }
    
    private func pumpFromUDP(debugPrint: @escaping DebugPrint, raw: NWConnection, completion: @escaping PumpCompletion) {
        raw.receiveMessage { (data, ctx, isComplete, error) in
            switch (data, ctx, isComplete, error) {
            case (_, _, _, .some(let error)):
                return completion(.failure(error))
            case (.some(let data), .some(let ctx), true, .none) where !ctx.isFinal:
                debugPrint("UDP->WS received \(data)")
                let wsCtx = ContentContext.wsBinary("wsudp")
                self.send(content: data, contentContext: wsCtx, completion: .contentProcessed({ error in
                    if let error = error {
                        return completion(.failure(error))
                    }
                    return self.pumpToUDP(debugPrint: debugPrint, raw: raw, completion: completion)
                }))
            case (let data, let ctx, let isComplete, let error):
                fatalError("Unexpected callback pumping UDP>WS: " + Self.callbackDesription(data: data, ctx: ctx, isComplete: isComplete, error: error))
            }
        }
    }
    
    private func pumpToUDP(debugPrint: @escaping DebugPrint, raw: NWConnection, completion: @escaping PumpCompletion) {
        self.receiveMessage { (data, ctx, isComplete, error) in
            switch (data, ctx, isComplete, error) {
            case (_, _, _, .some(let error)):
                return completion(.failure(error))
            case (.some(let data), .some(let ctx), true, .none) where !ctx.isFinal && ctx.wsMetadata?.opcode == .binary:
                debugPrint("WS->UDP received \(data)")
                raw.send(content: data, completion: .contentProcessed({ error in
                    if let error = error {
                        return completion(.failure(error))
                    }
                    return self.pumpToUDP(debugPrint: debugPrint, raw: raw, completion: completion)
                }))
            case (let data, let ctx, let isComplete, let error):
                fatalError("Unexpected callback pumping WS>UDP: " + Self.callbackDesription(data: data, ctx: ctx, isComplete: isComplete, error: error))
            }
        }
    }
    
    private static func callbackDesription(data: Data?, ctx: ContentContext?, isComplete: Bool, error: NWError?) -> String {
        "data=\(String(describing: data)), ctx.isFinal=\(String(describing: ctx?.isFinal)), ctx.opCode=\(String(describing: ctx?.wsMetadata?.opcode)) isComplete=\(isComplete), error=\(String(describing: error))"
    }
}

private extension NWConnection.ContentContext {
    var wsMetadata: NWProtocolWebSocket.Metadata? {
        self.protocolMetadata.first as? NWProtocolWebSocket.Metadata
    }

    static func wsText(_ identifier: String) -> NWConnection.ContentContext {
        return NWConnection.ContentContext(
            identifier: identifier,
            isFinal: false, // WS would fail, expects isFinal only on .close, plus closes both sides
            metadata: [
                NWProtocolWebSocket.Metadata(opcode: .text),
            ]
        )
    }

    static func wsBinary(_ identifier: String) -> NWConnection.ContentContext {
        return NWConnection.ContentContext(
            identifier: identifier,
            isFinal: false, // WS would fail, expects isFinal only on .close, plus closes both sides
            metadata: [
                NWProtocolWebSocket.Metadata(opcode: .binary),
            ]
        )
    }
}
