//
//  Config.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/31/21.
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "config")

// TODO: https://github.com/gonzalezreal/DefaultCodable
struct Config: Equatable, Hashable, Codable {
    var psk: String
    var acceptInbound: Bool
    private(set) var listeners: Set<Listener>
    var alwaysDark: Bool

    // Custom memberwise initialized that also does some validation.
    init(
        psk: String = "ChangeMe1234!",
        acceptInbound: Bool = true,
        listeners: Set<Listener> = [ .socks(.socks, .init()) ],
        alwaysDark: Bool = false
    ) {
        precondition(Self.areBindPortsUnique(listeners: listeners), "Bind port conflict")
        self.psk = psk
        self.acceptInbound = acceptInbound
        self.listeners = listeners
        self.alwaysDark = alwaysDark
    }
    
    enum ListenerType: String, Codable {
        case tcp
        case udp
        case socks
        
        var bindNamespace: BindPort.Namespace {
            switch self {
            case .tcp:   return .tcp
            case .udp:   return .udp
            case .socks: return .tcp
            }
        }
    }
    
    enum Listener: Equatable, Hashable {
        case tcp(NWEndpoint.Port, Via, Endpoint)
        case udp(NWEndpoint.Port, Via, Endpoint)
        case socks(NWEndpoint.Port, Via)
                
        var type: ListenerType {
            switch self {
            case .tcp(_, _, _): return .tcp
            case .udp(_, _, _): return .udp
            case .socks(_, _): return .socks
            }
        }

        var port: NWEndpoint.Port {
            switch self {
            case .tcp(let port, _, _),
                 .udp(let port, _, _),
                 .socks(let port, _):
                return port
            }
        }

        var bindPort: BindPort {
            BindPort(namespace: type.bindNamespace, number: port)
        }
            
        var via: Via {
            switch self {
            case .tcp(_, let via, _),
                 .udp(_, let via, _),
                 .socks(_, let via):
                return via
            }
        }
        
        var target: Endpoint? {
            switch self {
            case .tcp(_, _, let target),
                 .udp(_, _, let target):
                return target
            case .socks(_, _):
                return nil
            }
        }
    }
        
    struct Via: Equatable, Hashable, Codable {
        var nameFilter: String?
    }

    struct Endpoint: Equatable, Hashable, Codable {
        var host: String
        var port: NWEndpoint.Port
        
        var nw: NWEndpoint {
            NWEndpoint.hostPort(host: .name(host, nil), port: port)
        }
    }

    /// Returns `nil` if successful, `BindPort` if a bind port conflict would result.
    mutating func updateListener(old: Config.Listener?, new: Config.Listener?) -> BindPort? {
        if let new = new {
            if listeners.contains(where: { other in
                other.bindPort == new.bindPort &&
                other != old
            }) {
                return new.bindPort
            }
        }
        
        if let old = old {
            let removed = listeners.remove(old)
            precondition(removed != nil)
        }
        
        if let new = new {
            listeners.insert(new)
        }
        return nil
    }
    
    private static func areBindPortsUnique(listeners: Set<Listener>) -> Bool {
        var bindPorts: Set<BindPort> = []
        for listener in listeners {
            let (inserted, _) = bindPorts.insert(listener.bindPort)
            if !inserted {
                return false
            }
        }
        return true
    }
}

// Filesystem persistence
extension Config {
    private static let defaultURL: URL = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("jjproxy.json")
    
    static func restoreFromDefaultFile() throws -> Self {
        if FileManager.default.fileExists(atPath: defaultURL.path) {
            logger.log("Loading config file")
            do {
                return try JSONDecoder().decode(Self.self, from: try Data(contentsOf: defaultURL))
            } catch {
                logger.error("Could not decode config file: \(error.localizedDescription)")
                logger.error("Initializing with defaults")
                return Self()
            }
        } else {
            logger.log("No config file exists, initializing with defaults")
            return Self()
        }
    }
    
    func persistToDefaultFile() throws {
        logger.log("Persisting config file")
        try Data(try JSONEncoder().encode(self)).write(to: Self.defaultURL)
    }
}

extension Config.Listener: Codable {
    enum CodingKeys: CodingKey {
        case type, port, via, target
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(bindPort.number, forKey: .port)
        try container.encode(via, forKey: .via)
        try container.encodeIfPresent(target, forKey: .target)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Config.ListenerType.self, forKey: .type)
        let port = try container.decode(NWEndpoint.Port.self, forKey: .port)
        let via = try container.decode(Config.Via.self, forKey: .via)
        let target = try container.decodeIfPresent(Config.Endpoint.self, forKey: .target)
        
        switch type {
        case .tcp:   self = .tcp(port, via, target!)
        case .udp:   self = .udp(port, via, target!)
        case .socks: self = .socks(port, via)
        }
    }
}
