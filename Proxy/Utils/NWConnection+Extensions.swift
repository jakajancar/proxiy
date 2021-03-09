//
//  NWConnection+Extensions.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/3/21.
//

import Foundation
import Network

extension NWConnection {
    /// Reads exactly `length` bytes from the connection. Exactly one `completion` parameter will be non-`nil`.
    func receive(length: Int, expectComplete: Bool = false, completion: @escaping (Result<Data, NWError>) -> Void) {
        self.receive(minimumIncompleteLength: length, maximumLength: length) { (data, ctx, isComplete, error) in
            if let error = error {
                completion(.failure(error))
            } else if let data = data {
                // got enough data
                if isComplete && !expectComplete {
                    // If we get `length` bytes + EOF, in order to not swallow the EOF, unless
                    // expectComplete is true, we return .ENODATA as well.
                    completion(.failure(.posix(.ENODATA)))
                } else {
                    completion(.success(data))
                }
            } else {
                // not enough data
                completion(.failure(.posix(.ENODATA)))
            }
        }
    }
}
