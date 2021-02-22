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

///// Stores the `Config` and:
/////  1. Syncs it to persistent storage, and
/////  2. Maintains an up-to-date `Mesh` instance.
//class ConfigAndMesh: ObservableObject {
//    @Published var config: Config
//    @Published private(set) var mesh: Mesh
//    init(config: Config) {
//        self.config = config
//
//    }
//    private static func createMesh(_ config: Config) -> Mesh {
//        Mesh(deviceInfo: DeviceInfo.current, config: <#T##Config#>)
//    }
//}

@main
struct ProxyApp: App {
    @StateObject private var model = ProxyAppModel()
    
    var body: some Scene {
        WindowGroup {
            HomeView(
                config: $model.config,
                settingsPresented: $model.settingsPresented,
                mesh: model.mesh
            )
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
                    model.settingsPresented = true
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
            #endif
        }
    }
    
    init() {
        increaseFileDescriptorLimit(to: 8192)
    }
    
}

class ProxyAppModel: ObservableObject {
    @Published var settingsPresented: Bool = false
    @Published var config: Config {
        didSet {
            try! config.persistToDefaultFile()
            mesh.forceCancel()
            mesh = Mesh(deviceInfo: DeviceInfo.current, config: config)
        }
    }
    @Published var mesh: Mesh
    
    init() {
//        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
//            fatalError("Refusing to initialize the full (slow) app model in preview. Bug somewhere?")
//        }
        let initialConfig = try! Config.restoreFromDefaultFile()
        config = initialConfig
        mesh = Mesh(deviceInfo: DeviceInfo.current, config: initialConfig)
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
