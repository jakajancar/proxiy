//
//  NWConnection+Forwarding.swift
//  ProxyTests
//
//  Created by Jaka Jancar on 3/2/21.
//

import Foundation
import Network

// Forwarding of messages between connections.
//
// Keep in mind:
//  - TCP connections have 1 final message, cannot take 0-length messages (noop)
//  - UDP connections have unlimited non-final messages
//    (except 0-length message is counted as close: https://developer.apple.com/forums/thread/112917?login=true&page=1)
extension NWConnection {
    /// Forwards a single message (in pieces as they come in). Returns a boolean indicating if this is a final message.
    func forwardMessage(
        to: NWConnection,
        mappingContext mapper: @escaping (NWConnection.ContentContext) -> NWConnection.ContentContext,
        completion: @escaping (Result<Bool, NWError>) -> Void
    ) {
        self.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { (data, srcCtx, isComplete, error) in
//            print("\(srcCtx?.identifier) received data \(data), srcCtx.isfinal = \(srcCtx?.isFinal), isComplete = \(isComplete)")
            if let error = error {
                return completion(.failure(error))
            }
            guard let srcCtx = srcCtx else {
                fatalError("missing srcCtx?")
            }
            let dstCtx = mapper(srcCtx)
            to.send(content: data, contentContext: dstCtx, isComplete: isComplete, completion: .contentProcessed({ error in
                if let error = error {
                    return completion(.failure(error))
                }
                
                if isComplete {
                    return completion(.success(dstCtx.isFinal))
                } else {
                    // Recurse, but carrying over the already mapped context
                    //
                    // If we don't keep the existing context and just create a new one, the new
                    // one will never be used because the old one is not completed (assuming it's
                    // a multi-part one).
                    return self.forwardMessage(to: to, mappingContext: { _ in dstCtx }, completion: completion)
                }
            }))
        }
    }
    
    /// Forwards all messages, mapping each context.
    func forwardAllMessages(
        to: NWConnection,
        mappingContexts mapper: @escaping (NWConnection.ContentContext) -> NWConnection.ContentContext,
        completion: @escaping (Result<Void, NWError>) -> Void
    ) {
        forwardMessage(to: to, mappingContext: mapper) { result in
            switch result {
            case .failure(let error):
                return completion(.failure(error))
            case .success(true):
                return completion(.success(()))
            case .success(false):
                return self.forwardAllMessages(to: to, mappingContexts: mapper, completion: completion)
            }
        }
    }

    /// Forwards a signle message, mapping each context, in both directions.
    static func forwardMessageBetween(
        a: NWConnection,
        b: NWConnection,
        mappingContextFromA aMapper: @escaping (NWConnection.ContentContext) -> NWConnection.ContentContext,
        mappingContextFromB bMapper: @escaping (NWConnection.ContentContext) -> NWConnection.ContentContext,
        completion: @escaping (Result<Void, NWError>) -> Void
    ) {
        enum Status {
            case bothOpen
            case oneSideCleanlyClosed
            case oneSideFailed
        }

        var status = Status.bothOpen
        let wrappedCompletion = { (result: Result<Bool, NWError>) in
            switch (status, result) {
            case (.bothOpen, .success(_)):
                status = .oneSideCleanlyClosed
            case (.bothOpen, .failure(let error)):
                status = .oneSideFailed
                completion(.failure(error)) // fail immediately so pipe gets shut down eagerly
            case (.oneSideCleanlyClosed, .success(_)):
                completion(.success(()))
            case (.oneSideCleanlyClosed, .failure(let error)):
                completion(.failure(error))
            case (.oneSideFailed, _):
                break // already sent
            }
        }
        
        a.forwardMessage(to: b, mappingContext: aMapper, completion: wrappedCompletion)
        b.forwardMessage(to: a, mappingContext: bMapper, completion: wrappedCompletion)
    }
}
