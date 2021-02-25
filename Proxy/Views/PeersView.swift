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
        List(sortedPeers) { peer in
            PeerCell(peer: peer)
        }
        .navigationTitle("Peers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItemGroup(placement: .bottomBar) {
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
                    
                    Text(bandwidthFormatter.string(fromByteCount: peer.bytesPerSec) + "/sec")
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
                    mesh: MockMesh.forDevelopment
                )
            }
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)

            MyNavigationView {
                PeersView(
                    settingsAction: {},
                    mesh: MockMesh.forDevelopment
                )
            }
            .environment(\.forcedColorScheme, .dark)
            .previewDevice("Mac Catalyst")
            .previewLayout(.sizeThatFits)

        }
    }
}
