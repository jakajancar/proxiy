//
//  UserError.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/18/21.
//

import Foundation

struct UserError: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}

extension UserError: Identifiable {
    var id: String {
        message
    }
}
