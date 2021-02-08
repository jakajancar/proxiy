//
//  ClientRequest.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/5/21.
//

import Foundation
import Network

/// Data sent on the connection when a peer connects to another peer, after TLS auth.
struct PeerHello: Codable {
    let instanceID: InstanceID
}

extension NWConnection {
    func send(peerHello: PeerHello, completion: @escaping (NWError?) -> Void) {
        let jsonData = try! JSONEncoder().encode(peerHello)
        
        let length: UInt32 = UInt32(exactly: jsonData.count)!
        let lengthData = length.bigEndian.data

        self.send(content: lengthData, completion: .contentProcessed({ error in
            guard error == nil else { return completion(error) }

            self.send(content: jsonData, completion: .contentProcessed({ error in
                guard error == nil else { return completion(error) }

                completion(nil)
            }))
        }))
    }
    
    func receivePeerHello(completion: @escaping (PeerHello?, NWError?) -> Void) {
        self.receive(length: 4) { (data, error) in
            guard let data = data else { return completion(nil, error!) }
            
            let length = Int(UInt32(bigEndian: UInt32(data: data)!))
            
            self.receive(length: length) { (data, error) in
                guard let data = data else { return completion(nil, error!) }
                
                let req = try! JSONDecoder().decode(PeerHello.self, from: data)
                completion(req, nil)
            }
        }
    }
}
