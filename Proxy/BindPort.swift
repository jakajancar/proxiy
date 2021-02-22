//
//  BindPort.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/12/21.
//

import Foundation
import Network

/// Model for a local port that can be bound to. Two listeners cannot share the same bind port.
struct BindPort: Equatable, Hashable, Comparable, CustomDebugStringConvertible {
    var namespace: Namespace
    var number: NWEndpoint.Port

    enum Namespace: String, Codable {
        case tcp = "TCP"
        case udp = "UDP"
    }

    var debugDescription: String { "\(namespace) \(number)" }

    static func < (lhs: BindPort, rhs: BindPort) -> Bool {
        lhs.number.rawValue < rhs.number.rawValue ||
            lhs.number == rhs.number && lhs.namespace == .tcp && rhs.namespace == .udp
    }
}
