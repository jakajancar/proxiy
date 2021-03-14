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
import CoreLocation

let kAppName = "Proxiy"
private let logger = Logger(subsystem: "si.jancar.Proxiy", category: "app")

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
    @Published var locationListner: LocationListener?
    
    init() {
        // Config sync
        config = try! Config.restoreFromDefaultFile()
        $config
            .sink { config in try! config.persistToDefaultFile() }
            .store(in: &cancellables)
        
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" &&
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        {
            // Mesh updating based on meshConfig
            $config
                .map { config in config.meshConfig }
                .removeDuplicates()
                .sink { meshConfig in
                    logger.info("Recreating mesh")
                    self.mesh?.forceCancel()
                    // Wait a bit so that we can reuse local listener ports
                    DispatchQueue.main.async {
                        self.mesh = Mesh(deviceInfo: DeviceInfo.current, config: meshConfig)
                    }
                }
                .store(in: &cancellables)
            
            // LocationListener updating based on all sorts
            do {
                let inForeground1 = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification).map { _ in true }
                let inForeground2 = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).map { _ in false }
                let inForeground = inForeground1.merge(with: inForeground2)
                
                let locationMode = $config.map { config in config.locationMode }.removeDuplicates()
                let backgroundMode = $config.map { config in config.backgroundMode }.removeDuplicates()
                let havePeers = $mesh
                    .filter({ $0 != nil })
                    .flatMap { mesh in mesh!.objectWillChange }
                    .receive(on: DispatchQueue.main) // wait until it has changed
                    .map { Void in self.mesh!.peers.contains(where: { peer in !peer.isMe }) }
                    .removeDuplicates()
                
                locationMode.combineLatest(backgroundMode, inForeground, havePeers)
                    .map({ (locationMode: Config.LocationMode, backgroundMode, inForeground, havePeers) -> CLLocationAccuracy? in
                        logger.log("Location inputs: locationMode=\(String(describing: locationMode)), backgroundMode=\(String(describing: backgroundMode)), inForeground=\(inForeground), havePeers=\(havePeers)")

                        if locationMode != .off && (
                            inForeground ||
                            backgroundMode == .always ||
                            backgroundMode == .whilePeersConnected && havePeers
                        ) {
                            // Should be enabled
                            return locationMode == .bestAccuracy ? kCLLocationAccuracyBestForNavigation : kCLLocationAccuracyReduced
                        } else {
                            return nil
                        }
                    })
                    .removeDuplicates()
                    .sink(receiveValue: { [unowned self] accuracy in
                        self.locationListner?.cancel()
                        self.locationListner = nil
                        if let accuracy = accuracy {
                            logger.log("Location Listener starting with desired accuracy \(accuracy)")
                            self.locationListner = LocationListener(accuracy: accuracy)
                        } else {
                            logger.log("Location Listener disabled")
                        }
                    })
                    .store(in: &cancellables)
                
            }
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
