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
    @StateObject private var state = ProxyAppState()
    
    var body: some Scene {
        WindowGroup {
            if let mesh = state.mesh {
                HomeView(
                    config: $state.config,
                    settingsPresented: $state.settingsPresented,
                    mesh: mesh
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
                    state.settingsPresented = true
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
            #endif
        }
    }
    
    init() {
        increaseFileDescriptorLimit(to: 8192)
        UIApplication.shared.isIdleTimerDisabled = true
    }
}

class ProxyAppState: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var config: Config
    @Published var mesh: Mesh?
    @Published var settingsPresented: Bool = false
    
    init() {
        // Config sync
        config = try! Config.restoreFromDefaultFile()
        $config
            .sink { config in try! config.persistToDefaultFile() }
            .store(in: &cancellables)
        
        // Mesh
        $config
            .map { config in config.meshConfig }
            .removeDuplicates()
            .sink { meshConfig in
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                    logger.info("Recreating mesh")
                    self.mesh?.forceCancel()
                    self.mesh = Mesh(deviceInfo: DeviceInfo.current, config: meshConfig)
                }
            }
            .store(in: &cancellables)
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
