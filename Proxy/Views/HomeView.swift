//
//  ContentView.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/26/21.
//

import SwiftUI

struct HomeView<M: MeshViewModel>: View {
    @Binding var config: Config
    @ObservedObject var mesh: M
    @State private var settingsPresented = false
    
    var body: some View {
        VStack {
            ZStack(alignment: .leading) {
                Image("Header")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 100)
                
                HStack {
                    Text("Peers")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    
                    Button(action: { settingsPresented = true }, label: {
                        Image(systemName: "gearshape.fill")
                    })
                }
            }

            List(sortedPeers) { peer in
                PeerCell(peer: peer)
            }
        }
        .sheet(isPresented: $settingsPresented, content: {
            ConfigEditorView(
                nearbyDeviceNames: Set(mesh.peers.map({ peer in
                    peer.deviceInfo.name
                })),
                initialValue: config,
                saveAction: { new in
                    config = new
                }
            )
        })
        .withHostingWindow { window in
            #if targetEnvironment(macCatalyst)
            if let window = window {
                if let scene = window.windowScene {
                    // Hide titlebar
                    if let titlebar = scene.titlebar {
                        titlebar.titleVisibility = .hidden
                        titlebar.toolbar = nil
                    }
                }
            }
            #endif
        }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            config: .constant(Config.initial),
            mesh: MockMesh.forDevelopment
        )
        .previewDevice("iPhone 12 mini")
        .previewLayout(.sizeThatFits)
    }
}
