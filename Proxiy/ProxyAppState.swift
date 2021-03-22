//
//  ProxyAppState.swift
//  Proxiy
//
//  Created by Jaka Jancar on 3/15/21.
//

import Foundation
import Network
import Combine
import OSLog
import CoreLocation
import UIKit

private let logger = Logger(subsystem: "si.jancar.Proxiy", category: "appstate")

class ProxyAppState: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var config: Config
    @Published var locationListner: LocationListener?
    
    #if !MARKETING
    @Published var mesh: Mesh?

    init() {
        // Config sync
        config = try! Config.restoreFromDefaultFile()
        $config
            .sink { config in try! config.persistToDefaultFile() }
            .store(in: &cancellables)
        
        // Mesh changes are AppState changes
        $mesh
            .filter({ $0 != nil })
            .flatMap { mesh in mesh!.objectWillChange }
            .sink { _ in self.objectWillChange.send() }
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
    #else
    @Published var mesh: MockMesh?

    init() {
        // Marketing
        let idiom = UIDevice.current.userInterfaceIdiom
        let phone = MockPeer(
            isMe: idiom == .phone,
            deviceInfo: DeviceInfo(name: "Leah's iPhone", machine: "iPhone13,1"),
            inboundConnectionCount: 0,
            outboundConnectionCount: 0,
            bytesPerSec: 0
        )
        let macbook = MockPeer(
            isMe: idiom == .mac,
            deviceInfo: DeviceInfo(name: "Leah's MacBook Pro", machine: "MacBookPro16,1"),
            inboundConnectionCount: 0,
            outboundConnectionCount: 0,
            bytesPerSec: 0
        )
        let imac = MockPeer(
            deviceInfo: DeviceInfo(name: "Leah's iMac", machine: "iMac99,9"),
            inboundConnectionCount: 24,
            outboundConnectionCount: 0,
            bytesPerSec: 4203134
        )
        let ipad = MockPeer(
            isMe: idiom == .pad,
            deviceInfo: DeviceInfo(name: "Leah's iPad", machine: "iPad7,1"),
            inboundConnectionCount: 0,
            outboundConnectionCount: 0,
            bytesPerSec: 0
        )

        #if targetEnvironment(macCatalyst)
        config = Config(
            acceptInbound: true,
            listeners: [
                .socks(.init(integerLiteral: 1080), .init(nameFilter: phone.deviceInfo.name)),
                .socks(.init(integerLiteral: 1081), .init(nameFilter: macbook.deviceInfo.name)),
                .tcp(.init(integerLiteral: 8080), .init(nameFilter: macbook.deviceInfo.name), .init(host: "localhost", port: .init(integerLiteral: 8080))),
                .udp(.init(integerLiteral: 51820), .init(nameFilter: phone.deviceInfo.name), .init(host: "vpn.john.example", port: .init(integerLiteral: 51820)))
            ]
        )
        #else
        config = Config(
            acceptInbound: true
        )
        #endif

        mesh = MockMesh(status: .connected, peers: [phone, macbook, imac, ipad])
    }
    #endif
}
