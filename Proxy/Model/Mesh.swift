//
//  Mesh.swift
//  Proxy
//
//  Created by Jaka Jancar on 1/26/21.
//

import Foundation
import Network
import CryptoKit
import OSLog

typealias InstanceID = String

private let logger = Logger(subsystem: "si.jancar.Proxy", category: "mesh")

// TODO: consider waiting state everywhere

/// Subset of the config relevant to `Mesh`
struct MeshConfig: Equatable {
    var psk: String
    var acceptInbound: Bool
    var listeners: Set<Config.Listener>
}

class Mesh {
    private static let kBonjourServiceType: String = (Bundle.main.infoDictionary!["NSBonjourServices"] as! [String])[0]
    // BUG: https://developer.apple.com/forums/thread/673143
    private static let kUseTLSBetweenPeers: Bool = false
    
    private let deviceInfo: DeviceInfo
    private let config: MeshConfig
    private var psk: SymmetricKey
    
    fileprivate let myInstanceID: InstanceID = UUID().uuidString
    private var meshListener: NWListener!
    private var meshBrowser: NWBrowser!
    
    /// Peers indexed by instance, so that Bonjour updates can be easily applied and inbound connections easily tracked.
    @Published fileprivate var peerMap: [InstanceID : Peer] = [:]
    
    private var localListeners: [NWEndpoint.Port : NWListener] = [:]
    
    private var unidentifiedConnectionsFromPeer: Set<ConnectionFromPeer> = []
    
    init(deviceInfo: DeviceInfo, config: MeshConfig) {
        logger.log("Initializing")
        self.deviceInfo = deviceInfo
        self.config = config
        self.psk = SymmetricKey(data: SHA256.hash(data: config.psk.data(using: .utf8)!))
        
        self.refreshLocalListeners()
        self.recreateAndStartListener()
        self.recreateAndStartBrowser()
    }
    
    private func recreateAndStartListener() {
        let tcpOpts = NWProtocolTCP.Options()

        let params = NWParameters.init(
            tls: Mesh.kUseTLSBetweenPeers ? Self.tlsOptions(psk: psk) : nil,
            tcp: tcpOpts)
        params.includePeerToPeer = true
        
        let listener = try! NWListener(using: params)
        listener.service = NWListener.Service(
            name: self.myInstanceID,
            type: Mesh.kBonjourServiceType,
            domain: nil,
            txtRecord: PeerAdvertisement(
                deviceInfo: self.deviceInfo,
                acceptsInbound: config.acceptInbound
            ).toTxtRecord(using: self.psk)
        )
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                logger.log("Listener failed: \(String(describing: error))")
                self?.recreateAndStartListener()
            case .cancelled:
                break // todo
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.handleConnectionFromPeer(conn: conn)
        }
        
        self.meshListener = listener
        self.meshListener.start(queue: DispatchQueue.main)
    }
    
    private func recreateAndStartBrowser() {
        let params = NWParameters.tcp
        params.includePeerToPeer = true

        let browser = NWBrowser.init(
            for: .bonjourWithTXTRecord(type: Mesh.kBonjourServiceType, domain: nil),
            using: params)
        
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                logger.log("Browser failed: \(String(describing: error))")
                self?.recreateAndStartBrowser()
            case .cancelled:
                break // todo
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { [weak self] (results, changes) in
            self?.bonjourChanged(results: results, changes: changes)
        }
        
        self.meshBrowser = browser
        self.meshBrowser.start(queue: DispatchQueue.main)
    }
    
    private static func tlsOptions(psk: SymmetricKey) -> NWProtocolTLS.Options {
        let tlsOpts = NWProtocolTLS.Options()
        let secOpts = tlsOpts.securityProtocolOptions
        
        let pskData = psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let pskIdentityData = "proxy".data(using: .utf8)!.withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(
            secOpts,
            pskData as __DispatchData,
            pskIdentityData as __DispatchData)
        
        return tlsOpts
    }
    
    func forceCancel() {
        logger.log("Shutting down")
        self.meshListener.cancel()
        self.meshBrowser.cancel()
        
        for localListener in self.localListeners.values {
            localListener.cancel()
        }
        
        for peer in self.peerMap.values {
            peer.forceCancel()
        }
    }

    deinit {
        logger.log("De-initializing")
    }
    
    private func bonjourChanged(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        refreshPeers()
    }
    
    private func refreshPeers() {
        var valid: Set<InstanceID> = Set()
        
        for result in self.meshBrowser.browseResults {
            if case .service(name: let instanceID, type: _, domain: _, interface: _) = result.endpoint,
               case .bonjour(let txt) = result.metadata,
               let advertisement = PeerAdvertisement.fromTxtRecord(txt, using: self.psk)
            {
                valid.insert(instanceID)
                
                if let existingPeer = self.peerMap[instanceID] {
                    // Keep existing Peer
                    assert(existingPeer.endpoint == result.endpoint)
                    existingPeer.advertisement = advertisement
                } else {
                    // Create new Peer
                    self.peerMap[instanceID] = Peer(
                        mesh: self,
                        instanceID: instanceID,
                        endpoint: result.endpoint,
                        advertisement: advertisement
                    )
                }
            }
        }
        
        for (instanceID, peer) in self.peerMap where !valid.contains(instanceID) {
            peer.forceCancel()
            self.peerMap.removeValue(forKey: instanceID)
        }
    }
    
    private func selectPeer(via: Config.Via) -> Peer? {
        let matching = self.peerMap.values.filter { peer in
            peer.advertisement.acceptsInbound &&
                (via.nameFilter != nil ? via.nameFilter == peer.deviceInfo.name : true)
        }
        return matching.randomElement()
    }
    
    private func refreshLocalListeners() {
//        // Compute diff
//        let needed = Set(self.peers.map({ $0.advertisement.port }))
//        let existing = Set(self.localListeners.keys)
//        let toRemove = existing.subtracting(needed)
//        let toAdd = needed.subtracting(existing)
//
//        // Remove obsolete listeners
//        for port in toRemove {
//            logger.log("Removing listener on \(port.debugDescription)")
//            self.localListeners[port]!.cancel()
//            self.localListeners.removeValue(forKey: port)
//        }
//
//        // Add missing listeners
//        for port in toAdd {
//            logger.log("Adding listener on \(port.debugDescription)")
//            let listenerParams = NWParameters.tcp
//            listenerParams.requiredInterfaceType = .loopback
//            listenerParams.allowLocalEndpointReuse = true // TIME_WAIT doesn't seem to be applied, but just in case
//
//            let listener = try! NWListener(using: listenerParams, on: port)
//            listener.stateUpdateHandler = { state in
////                    print("local listener state = \(state)")
//            }
//            listener.newConnectionHandler = { [weak self] conn in
//                if let targetPeer = self.selectPeer(localPort: port) {
//                    let connToPeer = ConnectionToPeer(
//                        local: conn,
//                        peerEndpoint: targetPeer.endpoint,
//                        tlsOptions: Mesh.kUseTLSBetweenPeers ? Self.tlsOptions(psk: self.psk) : nil,
//                        myInstanceID: self.myInstanceID
//                    )
//                    targetPeer.connectionsTo.insert(connToPeer)
//                    connToPeer.completedHandler = { [weak targetPeer, weak connToPeer] in
//                        targetPeer?.connectionsTo.remove(connToPeer!)
//                    }
//                    connToPeer.start(queue: DispatchQueue.main)
//                } else {
//                    logger.log("no matching peer for connection to listener")
//                    conn.cancel()
//                }
//            }
//
//            self.localListeners[port] = listener
//            listener.start(queue: DispatchQueue.main)
//        }
    }

    private func handleConnectionFromPeer(conn: NWConnection) {
        let connFromPeer = ConnectionFromPeer(conn)
        self.unidentifiedConnectionsFromPeer.insert(connFromPeer)
        connFromPeer.identifiedHandler = { [weak self, weak connFromPeer] in
            let connFromPeer = connFromPeer!
            if let self = self {
                // Remove from unidentified
                self.unidentifiedConnectionsFromPeer.remove(connFromPeer)
                
                // Add to peer
                if let peer = self.peerMap[connFromPeer.peerInstanceID!] {
                    peer.connectionsFrom.insert(connFromPeer)
                } else {
                    logger.log("got request from peer not in peerMap")
                    connFromPeer.forceCancel()
                    return
                }
            }
        }
        connFromPeer.completedHandler = { [weak self, weak connFromPeer] in
            let connFromPeer = connFromPeer!
            if let self = self, let instanceID = connFromPeer.peerInstanceID, let peer = self.peerMap[instanceID] {
                peer.connectionsFrom.remove(connFromPeer)
            }
        }
        connFromPeer.start(queue: DispatchQueue.main)
    }
}

class Peer {
    fileprivate unowned let mesh: Mesh
    fileprivate let instanceID: InstanceID
    fileprivate let endpoint: NWEndpoint
    fileprivate var advertisement: PeerAdvertisement
    
    @Published var connectionsTo: Set<ConnectionToPeer> = [] // does not include local part
    @Published var connectionsFrom: Set<ConnectionFromPeer> = [] // does not include internet part
    
    fileprivate init(mesh: Mesh, instanceID: InstanceID, endpoint: NWEndpoint, advertisement: PeerAdvertisement) {
        self.mesh = mesh
        self.instanceID = instanceID
        self.endpoint = endpoint
        self.advertisement = advertisement
    }
    
    fileprivate func forceCancel() {
        for conn in self.connectionsTo {
            conn.forceCancel()
        }
        for conn in self.connectionsFrom {
            conn.forceCancel()
        }
    }
}

extension NWConnection: Equatable, Hashable {
    public static func == (lhs: NWConnection, rhs: NWConnection) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}

// MARK: ViewModel implementations

extension Mesh: MeshViewModel {
    var peers: Set<Peer> {
        Set(peerMap.values)
    }
}

extension Peer: PeerViewModel {
    var isMe: Bool {
        self.instanceID == self.mesh.myInstanceID
    }
    
    var deviceInfo: DeviceInfo {
        self.advertisement.deviceInfo
    }
    
    var acceptsInbound: Bool {
        self.advertisement.acceptsInbound
    }
    
    var connectionsFromCount: Int {
        self.connectionsFrom.count
    }
    
    var connectionsToCount: Int {
        self.connectionsTo.count
    }
    
    var bytesPerSec: Int64 { 0 }
}
