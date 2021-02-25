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

let kAppName = "Proxiy"
private let logger = Logger(subsystem: "si.jancar.Proxy", category: "app")

@main
struct ProxyApp: App {
    @StateObject private var state = ProxyAppState()
    
    var body: some Scene {
        MainScene(appState: state)
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
