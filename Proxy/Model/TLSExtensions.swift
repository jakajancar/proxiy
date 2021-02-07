//
//  TLSExtensions.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/4/21.
//
//
//  Extensions for TLS encryption between Mesh nodes. Is used for encryption
//  as well as protocol negotiation. Protocol (TCP/UDP/SOCKS) is sent in ALPN,
//  the hostname and port (for TCP/UDP) in SNI. We use this instead of sending
//  it within the stream since it conveniently works for TCP/TLS and UDP/DTLS.
//

import Foundation
import Network
import CryptoKit

extension NWProtocolTLS.Options {
    /// Shared security configuration for listener and outgoing connections.
    convenience init(usingPSK psk: SymmetricKey) {
        self.init()
        let secOpts = self.securityProtocolOptions
        
        // Add PSK
        let pskData = psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let pskIdentityData = "proxy".data(using: .utf8)!.withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(
            secOpts,
            pskData as __DispatchData,
            pskIdentityData as __DispatchData)
    
        
//        sec_protocol_options_set_min_tls_protocol_version(secOpts, .TLSv12)
//        sec_protocol_options_set_max_tls_protocol_version(secOpts, .TLSv12)
        
        // TODO: needed?
//        sec_protocol_options_append_tls_ciphersuite(
//            secOpts,
//            tls_ciphersuite_t(rawValue: tls_ciphersuite_t.RawValue(TLS_PSK_WITH_AES_256_GCM_SHA384))!)
        
//            sec_protocol_options_append_tls_ciphersuite(secOpts,
//                                tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!)

//        sec_protocol_options_set_pre_shared_key_selection_block(
//            secOpts,
//            { (sec, dispatchData, completed) in
//                print("SELECTION BLOCK! \(dispatchData)")
//                completed(pskIdentityData as __DispatchData)
//            },
//            DispatchQueue.main)

        
//        sec_protocol_options_set_verify_block(
//            secOpts,
//            { (metadata, trust, completed) in
//                completed(true)
//            },
//            DispatchQueue.main)
    }
}
