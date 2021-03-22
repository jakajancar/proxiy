//
//  PeersView.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/26/21.
//

import SwiftUI

struct PeersView<M: MeshViewModel>: View {
    let settingsAction: () -> Void
    @ObservedObject var mesh: M
    
    var body: some View {
        ZStack {
            List(sortedPeers) { peer in
                PeerCell(peer: peer)
            }
            
            if case .errors(let errors) = mesh.status {
                VStack {
                    Text(errors.joined(separator: "\n\n"))
                        .font(.system(.body, design: .monospaced))
                        .padding()
                    Spacer()
                }
            }
        }
        .navigationTitle("Peers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItemGroup(placement: .bottomBar) {
                let status: String = {
                    switch mesh.status {
                    case .starting:
                        return "Starting..."
                    case .searching:
                        return "Searching..."
                    case .connected:
                        return "Connected"
                    case .errors(_), .noLocalNetworkPermission:
                        return "Error"
                    }
                }()
                
                Spacer()

                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                #if !targetEnvironment(macCatalyst)
                Button(action: { settingsAction() }, label: {
                    Image(systemName: "gearshape")
                })
                #endif
            }
        })
    }
    
    var sortedPeers: [M.Peer] {
        mesh.peers.sorted { (a, b) -> Bool in
            a.bytesPerSec > b.bytesPerSec ||
                (a.bytesPerSec == b.bytesPerSec && a.deviceInfo.name < b.deviceInfo.name)
        }
    }
}

struct PeerCell<P: PeerViewModel>: View {
    @ObservedObject var peer: P

    private var bandwidthFormatter: ByteCountFormatter {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .decimal
        return fmt
    }
    
    var body: some View {
        HStack {
            Image(systemName: peer.deviceInfo.machineSymbolName)
                .frame(width: 35, alignment: .center)
                .foregroundColor(peer.acceptsInbound
                                    ? Color.primary
                                    : Color.primary.opacity(0.3))
            VStack(alignment: .leading) {
                Text(peer.deviceInfo.name)
                    .font(.body)
                    .lineLimit(1)

                HStack {
                    Text("Connections: \(peer.connectionsToCount) to / \(peer.connectionsFromCount) from")
                    
                    Spacer()
                    
                    Text(bandwidthFormatter.string(fromByteCount: Int64(peer.bytesPerSec)) + "/sec")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MyNavigationView {
                PeersView(
                    settingsAction: {},
                    mesh: MockMesh(
                        status: .searching,
                        peers: Set()
                    )
                )
            }
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)

            MyNavigationView {
                PeersView(
                    settingsAction: {},
                    mesh: MockMesh(
                        status: .connected,
                        peers: various.filter({ p in p.isMe })
                    )
                )
            }
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)

            MyNavigationView {
                PeersView(
                    settingsAction: {},
                    mesh: MockMesh(
                        status: .connected,
                        peers: various
                    )
                )
            }
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)
            
            MyNavigationView {
                PeersView(
                    settingsAction: {},
                    mesh: MockMesh(
                        status: .errors([
                            "Local listener TCP 1080 failed: POSIXErrorCode: Address already in use",
                            "Error 2"
                        ]),
                        peers: []
                    )
                )
            }
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)
            
//            MyNavigationView {
//                PeersView(
//                    settingsAction: {},
//                    mesh: MockMesh(
//                        status: .connected,
//                        peers: various
//                    )
//                )
//            }
//            .previewDevice("Mac Catalyst")
//            .previewLayout(.sizeThatFits)
        }
    }
    
    private static var various: Set<MockPeer> {
        [
            // This device
            MockPeer(isMe: true,
                     deviceInfo: DeviceInfo(
                        name: "Jaka's iPhone",
                        machine: "iPhone13,1"),
                     acceptsInbound: true,
                     inboundConnectionCount: 0,
                     outboundConnectionCount: 0,
                     bytesPerSec: 0),
            
            // Laptops
            MockPeer(deviceInfo: DeviceInfo(
                        name: "Jaka's MacBook Pro",
                        machine: "MacBookPro16,1"),
                     acceptsInbound: false,
                     inboundConnectionCount: 33,
                     outboundConnectionCount: 0,
                     bytesPerSec: 3293291843),
            
            MockPeer(deviceInfo: DeviceInfo(
                        name: "Leah's MacBook Pro",
                        machine: "MacBookPro15,2"),
                     acceptsInbound: true,
                     inboundConnectionCount: 8,
                     outboundConnectionCount: 0,
                     bytesPerSec: 23929100),

            // Tablet
            MockPeer(deviceInfo: DeviceInfo(
                        name: "Jaka's iPad Pro",
                        machine: "iPad7,1"),
                     acceptsInbound: true,
                     inboundConnectionCount: 0,
                     outboundConnectionCount: 0,
                     bytesPerSec: 0),

            
            // Test for long name
            MockPeer(deviceInfo: DeviceInfo(
                        name: "A device with a very very very very very very very long name",
                        machine: "Unknown"),
                    acceptsInbound: true,
                    inboundConnectionCount: 1234,
                    outboundConnectionCount: 9876,
                    bytesPerSec: 239291000
            ),

            // Test for sorting of rows with same bw
            MockPeer(deviceInfo: DeviceInfo(name: "Device A", machine: "Unknown"), bytesPerSec: 1),
            MockPeer(deviceInfo: DeviceInfo(name: "Device D", machine: "Unknown"), bytesPerSec: 1),
            MockPeer(deviceInfo: DeviceInfo(name: "Device C", machine: "Unknown"), bytesPerSec: 1),
            MockPeer(deviceInfo: DeviceInfo(name: "Device B", machine: "Unknown"), bytesPerSec: 1),
        ]
    }

}
