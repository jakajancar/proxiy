//
//  ProxyApp.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/26/21.
//

import SwiftUI
import Network
import Combine

@main
struct ProxyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(mesh: mesh)
        }
        
//        .commands {
//            CommandGroup(replacing: CommandGroupPlacement.newItem, addition: {
//                Button("Add Shape", action: { })
//                    .keyboardShortcut("N")
//            })
//        }
    }

//    @AppStorage("psk") var psk: String!// = nil //"ChangeMe1234!"
//    @AppStorage("port") var port: Int! // nil = Int.random(in: 44000..<45000)
    
    @StateObject var mesh: Mesh = Mesh(
        deviceInfo: DeviceInfo.current,
        config: Config(
            psk: "my secret key",
            allowInbound: true, //UIDevice.current.userInterfaceIdiom != .mac,
            listeners: Set([
                Config.Listener(localPort: 1080, via: Config.Via(nameFilter: nil), connectInstructions: .Socks)
            ])))
//    var mesh2 = Mesh(myPort: 50002)
    
//    private let sceneCancelable: AnyCancellable = NotificationCenter.default.publisher(for: UIScene.willConnectNotification).sink { (notification) in
//        #if targetEnvironment(macCatalyst)
//        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.forEach { windowScene in
//            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 480, height: 640)
//            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 480, height: 640)
//        }
//        #endif
//    }
    
    init() {
        // Initialize defaults
//        if self.psk == nil {
//            print("Setting default psk")
//            self.psk = "ChangeMe1234!"
//        }
        
    }
}
