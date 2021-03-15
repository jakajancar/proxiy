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
