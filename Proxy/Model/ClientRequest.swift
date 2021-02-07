//
//  ClientRequest.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/5/21.
//

import Foundation
import Network

/// Data sent on the connection when a peer connects to another peer, after TLS auth.
struct ClientRequest: Codable {
    let instanceID: InstanceID
}

extension NWConnection {
    func send(clientRequest: ClientRequest, completion: @escaping (NWError?) -> Void) {
        let jsonData = try! JSONEncoder().encode(clientRequest)
        
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
    
    func receiveClientRequest(completion: @escaping (ClientRequest?, NWError?) -> Void) {
        self.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, ctx, _, error) in
            guard data != nil else { return completion(nil, error) }
            
            let length = Int(UInt32(bigEndian: UInt32(data: data!)!))
            
            self.receive(minimumIncompleteLength: length, maximumLength: length) { (data, _, _, error) in
                guard error == nil else { completion(nil, error); return }
                
                let req = try! JSONDecoder().decode(ClientRequest.self, from: data!)
                completion(req, nil)
            }
        }
    }

}
