//
//  NWConnection+Extensions.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/3/21.
//

import Foundation
import Network

/// General-purpose utilities for `NWConnection`.
extension NWConnection {
    /// Reads exactly `length` bytes from the connection. Exactly one `completion` parameter will be non-`nil`.
    ///
    func receive(length: Int, expectFinal: Bool = true, completion: @escaping (Data?, NWError?) -> Void) {
        self.receive(minimumIncompleteLength: length, maximumLength: length) { (data, ctx, isComplete, error) in
            if let error = error {
                completion(nil, error)
            } else if let data = data {
                // got enough data
                if isComplete && !expectFinal {
                    // If we get `length` bytes + EOF, in order to not swallow the EOF, unless
                    // expectFinal is true, we return .ENODATA as well.
                    completion(nil, .posix(.ENODATA))
                } else {
                    completion(data, nil)
                }
            } else {
                // not enough data
                completion(nil, .posix(.ENODATA))
            }
        }
    }

    /// Receives all data from connection and sends it to another.
    /// Completion is called when `self` has FIN'd and all data and FIN has been sent, or after an error has occured either reading or writing.
    func transcieve(to: NWConnection, completion: @escaping (NWError?) -> Void) {
        self.receive(minimumIncompleteLength: 1, maximumLength: Int.max) { (content, contentContext, isComplete, receiveError) in
            if receiveError != nil {
//                print("transcieve received error while reading: \(receiveError)")
                return completion(receiveError)
            }
            
//            if isComplete {
//                print("got EOF from \(self), sending to \(to)")
//            }
            
            to.send(
                content: content,
                // When inbound isComplete, we're done. For some reason, ctx.isFinal is always true, so we cannot just forward it.
                contentContext: isComplete ? .finalMessage : .defaultMessage,
                isComplete: true, // proxy immediately, do not buffer
                completion: .contentProcessed({ (sendError) in
                    if sendError != nil {
//                        print("transcieve received error while sending: \(sendError)")
                        return completion(sendError)
                    }
                    
                    if isComplete {
//                        to.cancel()
                        completion(nil)
                    } else {
                        self.transcieve(to: to, completion: completion)
                    }
                }))
        }
    }
    
    /// Receives all data from connection and sends it to another, and vice versa.
    /// Both sides are progressed as much as possible, at which point completion is called with the first error, or nil if both connections have EOF'd.
    func transcieve(between other: NWConnection, completion: @escaping (NWError?) -> Void) {
        enum Status {
            case bothOpen
            case oneSideClosed(NWError?)
        }
        
        var status = Status.bothOpen
        let wrappedCompletion = { (error: NWError?) in
//            print("wrapped completion \(status) \(error)")
            switch status {
            case .bothOpen:
                status = .oneSideClosed(error)
            case .oneSideClosed(let previousError):
//                print("previousError = \(previousError), currentError = \(error)")
                if previousError != nil {
                    completion(previousError)
                } else {
                    completion(error) // may be nil
                }
            }
        }
        
        self.transcieve(to: other, completion: wrappedCompletion)
        other.transcieve(to: self, completion: wrappedCompletion)
    }
}
