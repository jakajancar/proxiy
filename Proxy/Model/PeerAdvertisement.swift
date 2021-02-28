//
//  PeerAdvertisement.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/29/21.
//

import Foundation
import Network
import CryptoKit
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "peeradvertisement")

/// Details a peer broadcasts on the network. Only visible within members.
struct PeerAdvertisement: Codable {
    let deviceInfo: DeviceInfo
    let acceptsInbound: Bool
//    let port: NWEndpoint.Port
    // hasInternet? (dynamic)
}

/// TXT serialization.
extension PeerAdvertisement {
    func toTxtRecord(using key: SymmetricKey) -> NWTXTRecord {
        let jsonData = try! JSONEncoder().encode(self)
        let box = try! ChaChaPoly.seal(jsonData, using: key)
        let boxCombined = box.combined
        let base64 = boxCombined.base64EncodedString()
        return NWTXTRecord.init(["peerinfo": base64])
    }
    
    static func fromTxtRecord(_ txtRecord: NWTXTRecord, using key: SymmetricKey) -> Self? {
        guard let base64 = txtRecord["peerinfo"] else {
            logger.log("malformed TXT")
            return nil
        }
        guard let boxCombined = Data(base64Encoded: base64) else {
            logger.log("malformed box format (not base64)")
            return nil
        }
        guard let box = try? ChaChaPoly.SealedBox(combined: boxCombined) else {
            logger.log("malformed box format (box)")
            return nil
        }
        guard let jsonData = try? ChaChaPoly.open(box, using: key) else {
            logger.log("ignoring peer (wrong key)")
            return nil
        }
        // Correct version (not yet checked for v1) and correct key, should be OK from here
        return try! JSONDecoder().decode(PeerAdvertisement.self, from: jsonData)
    }
}
