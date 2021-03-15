//
//  Result+Extensions.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/18/21.
//

import Foundation

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success(_): return true
        case .failure(_): return false
        }
    }
    
    var isFailure: Bool {
        !isSuccess
    }
}
