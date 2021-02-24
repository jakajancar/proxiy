//
//  ProxyApp.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/26/21.
//

import SwiftUI
import Network
import Combine
import OSLog

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "app")
private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

@main
struct ProxyApp: App {
    @State private var config: Config
    @State private var mesh: Mesh?
    @State private var settingsPresented: Bool = false
    
    private var cancellables = Set<AnyCancellable>()

    var body: some Scene {
        WindowGroup {
            if !isPreview {
                HomeView(
                    config: $config,
                    settingsPresented: $settingsPresented,
                    mesh: mesh!
                )
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
            CommandGroup(after: .appInfo) {
                Button("Preferences...") {
                    settingsPresented = true
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
            #endif
        }
        .onChange(of: config) { state in
            try! config.persistToDefaultFile()
            mesh!.forceCancel()
            mesh = Mesh(deviceInfo: DeviceInfo.current, config: config)
        }
    }
    
    init() {
        increaseFileDescriptorLimit(to: 8192)
        
        let initialConfig = try! Config.restoreFromDefaultFile()
        _config = State(initialValue: initialConfig)
        if !isPreview {
            _mesh = State(initialValue: Mesh(deviceInfo: DeviceInfo.current, config: initialConfig))
        }
    }
    
}

func increaseFileDescriptorLimit(to: rlim_t) {
    var rlim: rlimit = .init()
    if getrlimit(RLIMIT_NOFILE, &rlim) == 0 {
        print("Soft limit: \(rlim.rlim_cur), Hard limit: \(rlim.rlim_max)")
    } else {
        print("Unable to get file descriptor limits")
    }
    
    rlim.rlim_cur = to
    
    if setrlimit(RLIMIT_NOFILE, &rlim) == 0 {
        print("Increased rlimit")
    } else {
        print("Unable to set file descriptor limits")
    }
    
    if getrlimit(RLIMIT_NOFILE, &rlim) == 0 {
        print("Soft limit: \(rlim.rlim_cur), Hard limit: \(rlim.rlim_max)")
    } else {
        print("Unable to get file descriptor limits")
    }
}

func fileDescriptorCount() -> Int {
    var inUseDescCount = 0
    let descCount = getdtablesize()
    for descIndex in 0..<descCount {
        if fcntl(descIndex, F_GETFL) >= 0 {
            inUseDescCount += 1
        }
    }
    return inUseDescCount
}
