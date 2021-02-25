//
//  MainScene.swift
//  Proxiy
//
//  Created by Jaka Jancar on 2/25/21.
//

import SwiftUI

struct MainScene: Scene {
    @ObservedObject var appState: ProxyAppState    
    @State private var settingsPresented: Bool = false
    /// About can be pushed from Settings (iOS) or modally globaly (macOS). This models the latter.
    @State private var modalAboutPresented: Bool = false

    var body: some Scene {
        WindowGroup {
            if let mesh = appState.mesh {
                HomeView(
                    config: $appState.config,
                    settingsPresented: $settingsPresented,
                    mesh: mesh
                )
                .sheet(isPresented: $modalAboutPresented) {
                    NavigationView {
                        AboutView(config: appState.config)
                            .navigationBarHidden(true)
                            .primaryButton("Done") {
                                modalAboutPresented = false
                            }
                    }
                }
            }
        }
        .commands {
            #if targetEnvironment(macCatalyst)
            // As of 2021-02-22:
            //   - The Settings scene does not work under Catalyst
            //   - I cannot figure out how to have multiple scenes to show Preferences
            //     in own window, so we still use a modal, just like on iOS.
            //   - .appSettings group is not shown, even if we replace it here,
            //     so we add to the end of the .appInfo group.
            CommandGroup(replacing: .appInfo) {
                Button("About \(kAppName)") {
                    // Need to check no modal yet or they will get stuck
                    if !settingsPresented && !modalAboutPresented {
                        modalAboutPresented = true
                    }
                }
                
                Button("Preferences...") {
                    // Need to check no modal yet or they will get stuck
                    if !settingsPresented && !modalAboutPresented {
                        settingsPresented = true
                    }
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
            
            CommandGroup(replacing: .help) {
                ContactUsButton(config: appState.config)
            }
            #endif
        }
    }
}

//struct MainScene_Previews: PreviewProvider {
//    static var previews: some View {
//        MainScene()
//    }
//}
