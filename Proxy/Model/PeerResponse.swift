//
//  PeerReply.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/2/21.
//

import Foundation
import Network

/// Response to a `PeerRequest`. If no error, the connection has been established.
struct PeerResponse: Codable {
    let error: NWError?
}

extension NWError: Codable {
    enum CodingKeys: CodingKey {
        case type, code
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .posix(let code):
            try container.encode("posix", forKey: .type)
            try container.encode(code.rawValue, forKey: .code)
        case .dns(let code):
            try container.encode("dns", forKey: .type)
            try container.encode(code, forKey: .code)
        case .tls(let code):
            try container.encode("tls", forKey: .type)
            try container.encode(code, forKey: .code)
        @unknown default:
            try container.encode("posix", forKey: .type)
            try container.encode(EPROGMISMATCH, forKey: .code)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let code = try container.decode(Int32.self, forKey: .type)
        switch type {
        case "posix":
            self = .posix(POSIXErrorCode(rawValue: code)!)
        case "dns":
            self = .dns(code)
        case "tls":
            self = .tls(code)
        default:
            self = .posix(POSIXErrorCode.EPROGMISMATCH)
        }
    }
}
