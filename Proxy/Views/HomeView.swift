//
//  ContentView.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/26/21.
//

import SwiftUI

struct HomeView<M: MeshViewModel>: View {
    @Binding var config: Config
    @Binding var settingsPresented: Bool
    @ObservedObject var mesh: M
    
    var body: some View {
        NavigationView {
            List(sortedPeers) { peer in
                PeerCell(peer: peer)
            }
            .navigationTitle("Peers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    #if !targetEnvironment(macCatalyst)
                    Button(action: { settingsPresented = true }, label: {
                        Image(systemName: "gearshape.fill")
                    })
                    #endif
                }
            })
            .sheet(isPresented: $settingsPresented, content: {
                ConfigEditorView(
                    nearbyDeviceNames: Set(mesh.peers.map({ peer in
                        peer.deviceInfo.name
                    })),
                    config: $config
                )
            })
            .withHostingWindow { window in
                // replace with windowStyle / windowToolbarStyle
                #if targetEnvironment(macCatalyst)
                if let window = window {
                    if let scene = window.windowScene {
                        // Hide titlebar
                        if let titlebar = scene.titlebar {
                            titlebar.titleVisibility = .hidden
                            titlebar.toolbar = nil
                        }
//                        if let sizeRestrictions = scene.sizeRestrictions {
////                            let size = CGSize(width: 320, height: 600)
////                            sizeRestrictions.minimumSize = size
////                            sizeRestrictions.maximumSize = size
//                        }
                    }
                }
                #endif
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .colorScheme(alwaysDark: config.alwaysDark)
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
//        Text("\(peer.name) (\(peer.inboundConnectionCount) in, \(peer.outboundConnectionCount) out)")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView(
                config: .constant(Config.initial),
                settingsPresented: .constant(false),
                mesh: MockMesh.forDevelopment
            )
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)

            let darkConfig: Config = {
                var c = Config.initial
                c.alwaysDark = true
                return c
            }()
            
            HomeView(
                config: .constant(darkConfig),
                settingsPresented: .constant(false),
                mesh: MockMesh.forDevelopment
            )
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)
        }
    }
}
