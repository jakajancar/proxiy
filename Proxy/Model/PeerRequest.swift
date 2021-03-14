//
//  ClientRequest.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/5/21.
//

import Foundation
import Network

/// Data sent on the connection when a peer connects to another peer to establish a tunnel.
struct PeerRequest: Codable {
    let instanceID: InstanceID
    let instructions: ConnectInstructions
    
    // Subset of `Config.Listener` that is relevant to the peer
    enum ConnectInstructions {
        case tcp(Config.Endpoint)
        case udp(Config.Endpoint)
        
        var target: Config.Endpoint {
            switch self {
            case .tcp(let target),
                 .udp(let target):
                return target
            }
        }
    }
}

extension PeerRequest.ConnectInstructions: Codable {
    enum CodingKeys: CodingKey {
        case type, target
    }
    
    private var type: BindPort.Namespace {
        switch self {
        case .tcp(_): return .tcp
        case .udp(_): return .udp
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(target, forKey: .target)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BindPort.Namespace.self, forKey: .type)
        let target = try container.decodeIfPresent(Config.Endpoint.self, forKey: .target)
        
        switch type {
        case .tcp:   self = .tcp(target!)
        case .udp:   self = .udp(target!)
        }
    }
}
