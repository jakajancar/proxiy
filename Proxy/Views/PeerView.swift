//
//  PeerView.swift
//  Proxy
//
//  Created by Jaka Jancar on 2/1/21.
//

import SwiftUI

struct PeerView<P: PeerViewModel>: View {
    @ObservedObject var peer: P

    private var bandwidthFormatter: ByteCountFormatter {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .decimal
        return fmt
    }
    
    var body: some View {
        HStack {
            Image(systemName: peer.deviceInfo.machineSymbolName)
            VStack(alignment: .leading) {
                Text(peer.deviceInfo.name)
                    .font(.body)
                    .lineLimit(1)

                HStack {
                    Text("Connections: \(peer.connectionsToCount) to / \(peer.connectionsFromCount) from")
                    
                    Spacer()
                    
                    Text(bandwidthFormatter.string(fromByteCount: peer.bytesPerSec) + "/sec")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
//        Text("\(peer.name) (\(peer.inboundConnectionCount) in, \(peer.outboundConnectionCount) out)")
    }
}

//struct PeerView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            PeerView(
//                peer: MockPeer(
//                    name: "Jaka's iPhone",
//                    inboundConnectionCount: 0,
//                    outboundConnectionCount: 12,
//                    bytesPerSec: 0
//                )
//            )
//            PeerView(
//                peer: MockPeer(
//                    name: "A device with a very very very very very very very long name",
//                    inboundConnectionCount: 1234,
//                    outboundConnectionCount: 2345,
//                    bytesPerSec: 3293291843
//                )
//            )
//        }
//        .previewLayout(.sizeThatFits)
//    }
//}
