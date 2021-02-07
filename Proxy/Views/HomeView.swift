//
//  ContentView.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/26/21.
//

import SwiftUI
import ModalView

// https://www.hackingwithswift.com/quick-start/swiftui
struct HomeView<M: MeshViewModel>: View {
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
                    
                    ModalPresenter {
                        ModalLink(destination: SettingsView.init(dismiss:)) {
                                Image(systemName: "gearshape.fill")
                        }
                    }
                }
            }

            List(self.sortedPeers) { peer in
                PeerView(peer: peer)
            }
        }
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
//
//    var body: some View {
//        TabView {
//            VStack {
//                HStack {
//                    Text("Peers")
//                        .font(.title)
//                    Spacer()
//                }
//                Text("Num peers: \(self.mesh.peers.count)")
//                    .padding()
//                List(Array(mesh.peers)) { peer in
//                    PeerView(peer: peer)
//                }
//            }
//            .tabItem {
//                Text("Network")
//                Image(systemName: "network")
//            }
//
//            VStack {
//            }
//            .tabItem {
//                Text("Tunnels")
//                Image(systemName: "tram.tunnel.fill")
//            }
//
//            VStack {
//            }
//            .tabItem {
//                Text("Settings")
//                Image(systemName: "gear")
//            }
//        }
//    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            mesh: MockMesh(peers: [
                // This device
                MockPeer(deviceInfo: DeviceInfo(
                            name: "Jaka's iPhone",
                            machine: "iPhone13,1"),
                         inboundConnectionCount: 0,
                         outboundConnectionCount: 0,
                         bytesPerSec: 0),
                
                // Laptops
                MockPeer(deviceInfo: DeviceInfo(
                            name: "Jaka's MacBook Pro",
                            machine: "MacBookPro16,1"),
                         inboundConnectionCount: 33,
                         outboundConnectionCount: 0,
                         bytesPerSec: 3293291843),
                
                MockPeer(deviceInfo: DeviceInfo(
                            name: "Leah's MacBook Pro",
                            machine: "MacBookPro15,2"),
                         inboundConnectionCount: 8,
                         outboundConnectionCount: 0,
                         bytesPerSec: 23929100),

                // Tablet
                MockPeer(deviceInfo: DeviceInfo(
                            name: "Jaka's iPad Pro",
                            machine: "iPad7,1"),
                         inboundConnectionCount: 0,
                         outboundConnectionCount: 0,
                         bytesPerSec: 0),

                
                // Test for long name
                MockPeer(deviceInfo: DeviceInfo(
                            name: "A device with a very very very very very very very long name",
                            machine: "Unknown"),
                    inboundConnectionCount: 1234,
                    outboundConnectionCount: 9876,
                    bytesPerSec: 239291000
                ),

                // Test for sorting of rows with same bw
                MockPeer(deviceInfo: DeviceInfo(name: "Device A", machine: "Unknown"), bytesPerSec: 1),
                MockPeer(deviceInfo: DeviceInfo(name: "Device D", machine: "Unknown"), bytesPerSec: 1),
                MockPeer(deviceInfo: DeviceInfo(name: "Device C", machine: "Unknown"), bytesPerSec: 1),
                MockPeer(deviceInfo: DeviceInfo(name: "Device B", machine: "Unknown"), bytesPerSec: 1),

            ]))
            .previewDevice("iPhone 12 mini")
            .previewLayout(.sizeThatFits)
    }
}
