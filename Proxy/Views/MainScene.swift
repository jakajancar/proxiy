//
//  MainScene.swift
//  Proxiy
//
//  Created by Jaka Jancar on 2/25/21.
//

import SwiftUI


struct MainScene: Scene {
    @ObservedObject var appState: ProxyAppState
    @State private var activeSheet: ActiveSheet?
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    private enum ActiveSheet: Identifiable {
        case settings
        case about
        var id: Self { self }
    }
    
    var body: some Scene {
        WindowGroup {
            if let mesh = appState.mesh {
                MyNavigationView {
                    PeersView(
                        settingsAction: { activeSheet = .settings },
                        mesh: mesh
                    )
                    .sheet(item: $activeSheet) { sheet in
                        MyNavigationView {
                            switch sheet {
                            case .settings:
                                SettingsView(
                                    nearbyDeviceNames: Set(mesh.peers.map({ peer in
                                        peer.deviceInfo.name
                                    })),
                                    config: $appState.config
                                )
                            case .about:
                                AboutView(config: appState.config)
                                .navigationBarHidden(true)
                                .primaryButton("Done") {
                                    activeSheet = nil
                                }
                            }
                        }
                    }
                }
                .preferredColorScheme(ColorScheme(appState.config.alwaysDark ? .dark : UITraitCollection.current.userInterfaceStyle)!)
                .withHostingWindow { window in
                    #if targetEnvironment(macCatalyst)
                    if let window = window {
                        if let scene = window.windowScene {
                            // Hide titlebar
                            // replace with windowStyle / windowToolbarStyle once available for Catalyst
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
        }
        .commands {
            // As of 2021-02-22:
            //   - The Settings scene does not work under Catalyst
            //   - I cannot figure out how to have multiple scenes to show Preferences
            //     in own window, so we still use a modal, just like on iOS.
            //   - .appSettings group is not shown, even if we replace it here,
            //     so we add to the end of the .appInfo group.
            CommandGroup(replacing: .appInfo) {
                Button("About \(kAppName)") {
                    activeSheet = .about
                }
                
                Button("Preferences...") {
                    activeSheet = .settings
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
            
            CommandGroup(replacing: .help) {
                ContactUsButton(config: appState.config)
            }
        }
    }
}

//struct MainScene_Previews: PreviewProvider {
//    static var previews: some View {
//        MainScene()
//    }
//}
