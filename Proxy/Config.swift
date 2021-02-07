//
//  Config.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/31/21.
//

import Foundation
import Network

struct Config: Codable {
    struct Listener: Equatable, Hashable, Codable {
        var localPort: NWEndpoint.Port
        var via: Via
        var connectInstructions: ConnectInstructions
    }

    struct Via: Equatable, Hashable, Codable {
        var nameFilter: String?
    }

    enum ConnectInstructions: Equatable, Hashable {
        case Tcp(remoteHost: String, remotePort: NWEndpoint.Port)
        case Udp(remoteHost: String, remotePort: NWEndpoint.Port)
        case Socks
    }

    var psk: String
    var allowInbound: Bool
    var listeners: Set<Listener>
}

extension NWEndpoint.Port: Codable {
}

extension Config.ConnectInstructions: Codable {
    init(from decoder: Decoder) throws {
        let helper = try! Helper(from: decoder)
        switch helper.proto {
        case "tcp":
            self = .Tcp(remoteHost: helper.remoteHost!, remotePort: NWEndpoint.Port(rawValue: helper.remotePort!)!)
        case "udp":
            self = .Udp(remoteHost: helper.remoteHost!, remotePort: NWEndpoint.Port(rawValue: helper.remotePort!)!)
        case "socks":
            self = .Socks
        default:
            fatalError("Invalid proto \(helper.proto)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        let helper: Helper
        switch self {
        case .Tcp(remoteHost: let remoteHost, remotePort: let remotePort):
            helper = Helper(proto: "tcp", remoteHost: remoteHost, remotePort: remotePort.rawValue)
        case .Udp(remoteHost: let remoteHost, remotePort: let remotePort):
            helper = Helper(proto: "udp", remoteHost: remoteHost, remotePort: remotePort.rawValue)
        case .Socks:
            helper = Helper(proto: "socks")
        }
        try! helper.encode(to: encoder)
    }
    
    private struct Helper: Codable {
        var proto: String
        var remoteHost: String?
        var remotePort: UInt16?
    }

}
