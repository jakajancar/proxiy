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
import Combine

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
    
    private let deviceInfo: DeviceInfo
    private let config: MeshConfig
    private var psk: SymmetricKey
    
    fileprivate let myInstanceID: InstanceID = UUID().uuidString
    fileprivate var localListeners: [NWListener]!
    fileprivate var meshListener: NWListener!
    fileprivate var meshBrowser: NWBrowser!
    
    // Reset to false on successful start. Used to throttle retriest to at most once.
    private var meshListenerRetried: Bool = false
    private var meshBrowserRetried: Bool = false

    /// Peers indexed by instance, so that Bonjour updates can be easily applied and inbound connections easily tracked.
    @Published fileprivate var peerMap: [InstanceID : Peer] = [:]

    /// Local connections that have not yet chosen a peer to connect to
    private var unassociatedLocalConnections = ConnectionSet<ConnectionForPeer>()
    
    /// Connections from peers before the TLS handshake has been performed and `PeerRequest` (containing the peer's `InstanceID`) has been received.
    private var unidentifiedConnectionsFromPeer = ConnectionSet<ConnectionFromPeer>()

    init(deviceInfo: DeviceInfo, config: MeshConfig) {
        logger.log("Initializing")
        self.deviceInfo = deviceInfo
        self.config = config
        self.psk = SymmetricKey(data: SHA256.hash(data: config.psk.data(using: .utf8)!))
        
        self.initLocalListeners()
        self.recreateAndStartMeshListener()
        self.recreateAndStartMeshBrowser()
    }
    
    private func recreateAndStartMeshListener() {
        let params = self.meshParameters()
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
            guard let self = self else { return }
            
            switch state {
            case .ready:
                // Reset retries
                self.meshListenerRetried = false
            case .failed(let error):
                // This is expected after suspension (-65569: DefunctConnection)
                logger.log("Listener failed: \(String(describing: error))")
                if !self.meshListenerRetried {
                    self.meshListenerRetried = true
                    self.recreateAndStartMeshListener()
                }
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
    
    private func recreateAndStartMeshBrowser() {
        let params = NWParameters.tcp
        params.includePeerToPeer = true

        let browser = NWBrowser.init(
            for: .bonjourWithTXTRecord(type: Mesh.kBonjourServiceType, domain: nil),
            using: params)
        
        browser.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                // Reset retries
                self.meshBrowserRetried = false
            case .failed(let error):
                // This is expected after suspension (-65569: DefunctConnection)
                logger.log("Browser failed: \(String(describing: error))")
                if !self.meshBrowserRetried {
                    self.meshBrowserRetried = true
                    self.recreateAndStartMeshBrowser()
                }
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
    
    /// Parameters for `meshListener` and connections to it.
    private func meshParameters() -> NWParameters {
        // WebSocket
        let wsOpts = NWProtocolWebSocket.Options()
        wsOpts.skipHandshake = true
        wsOpts.autoReplyPing = true // not really used atm

        // TLS
        let tlsOpts = NWProtocolTLS.Options()
        let secOpts = tlsOpts.securityProtocolOptions
        let pskData = self.psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let pskIdentityData = "proxiy".data(using: .utf8)!.withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(
            secOpts,
            pskData as __DispatchData,
            pskIdentityData as __DispatchData)
        
        // TCP
        let tcpOpts = NWProtocolTCP.Options()
        tcpOpts.noDelay = true
        
        let params = NWParameters(tls: tlsOpts, tcp: tcpOpts)
        params.defaultProtocolStack.applicationProtocols.insert(wsOpts, at: 0)
        
        return params
    }
    
    func forceCancel() {
        logger.log("Cancelling")
        for localListener in self.localListeners {
            localListener.cancel()
        }

        self.meshListener.cancel()
        self.meshBrowser.cancel()
        
        for peer in self.peerMap.values {
            peer.forceCancel()
        }
    }

    deinit {
        logger.log("De-initializing")
    }
    
    private func bonjourChanged(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let new):
                self.insertOrUpdatePeer(result: new)
            case .removed(let old):
                self.removePeer(result: old)
            case .changed(old: let old, new: let new, flags: _):
                assert(old.endpoint == new.endpoint)
                self.insertOrUpdatePeer(result: new)
            default:
                break
            }
        }
    }

    private func insertOrUpdatePeer(result: NWBrowser.Result) {
        if case .service(name: let instanceID, type: _, domain: _, interface: _) = result.endpoint {
            if case .bonjour(let txt) = result.metadata {
                if let advertisement = PeerAdvertisement.fromTxtRecord(txt, using: self.psk) {
                    if let existingPeer = self.peerMap[instanceID] {
                        // Update existing
                        existingPeer.advertisement = advertisement
                    } else {
                        // Add new
                        self.peerMap[instanceID] = Peer(
                            mesh: self,
                            instanceID: instanceID,
                            endpoint: result.endpoint,
                            advertisement: advertisement)
                    }
                } else {
                    // Other network
                    self.removePeer(result: result)
                }
            } else {
                // No metadata. Happens when disconnecting cable while debugging on device, and perhaps on other interface changes. Ignore update.
            }
        } else {
            fatalError("non-service endpoint: \(result)")
        }
    }

    private func removePeer(result: NWBrowser.Result) {
        if case .service(name: let instanceID, type: _, domain: _, interface: _) = result.endpoint {
            if let peer = self.peerMap.removeValue(forKey: instanceID) {
                peer.forceCancel()
            }
        } else {
            fatalError("non-service endpoint: \(result)")
        }
    }
    
    private func selectPeer(via: Config.Via) -> Peer? {
        let matching = self.peerMap.values.filter { peer in
            peer.advertisement.acceptsInbound &&
                (via.nameFilter != nil ? via.nameFilter == peer.deviceInfo.name : true)
        }
        return matching.randomElement()
    }

    private func initLocalListeners() {
        self.localListeners = self.config.listeners.map { listenerConfig in
            // Create local listener
            let listenerParams: NWParameters
            switch listenerConfig.bindPort.namespace {
            case .tcp:
                listenerParams = NWParameters.tcp
            case .udp:
                listenerParams = NWParameters.udp
            }
            listenerParams.requiredInterfaceType = .loopback
            listenerParams.allowLocalEndpointReuse = true // TIME_WAIT doesn't seem to be applied, but just in case

            let listener = try! NWListener(using: listenerParams, on: listenerConfig.bindPort.number)
            listener.stateUpdateHandler = { state in
                // TODO: error handling
            }

            listener.newConnectionHandler = { [weak self] conn in
                self?.handleLocalConnection(listenerConfig: listenerConfig, conn: conn)
            }

            listener.start(queue: DispatchQueue.main)
            return listener
        }
    }
    
    private func handleLocalConnection(listenerConfig: Config.Listener, conn: NWConnection) {
        let localConn = ConnectionForPeer(myInstanceID: self.myInstanceID, listenerConfig: listenerConfig, local: conn)
        self.unassociatedLocalConnections.insert(localConn)
        localConn.connectPeer = { [weak self, unowned localConn] via in
            if let self = self, let peer = self.selectPeer(via: via) {
                self.unassociatedLocalConnections.remove(localConn)
                peer.connectionsTo.insert(localConn)

                return NWConnection(to: peer.endpoint, using: self.meshParameters())
            } else {
                return nil // no matching peer or mesh shut down
            }
        }
        localConn.start(queue: DispatchQueue.main)
    }

    private func handleConnectionFromPeer(conn: NWConnection) {
        if !self.config.acceptInbound {
            conn.cancel()
            return
        }
        
        let connFromPeer = ConnectionFromPeer(conn)
        self.unidentifiedConnectionsFromPeer.insert(connFromPeer)
        connFromPeer.identifiedHandler = { [weak self, unowned connFromPeer] peerInstanceID in
            if let self = self, let peer = self.peerMap[peerInstanceID] {
                self.unidentifiedConnectionsFromPeer.remove(connFromPeer)
                peer.connectionsFrom.insert(connFromPeer)
                return true
            } else {
                logger.warning("got request from unknown peer or mesh shut down")
                return false
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
    
    fileprivate var connectionsTo = ConnectionSet<ConnectionForPeer>()
    fileprivate var connectionsFrom = ConnectionSet<ConnectionFromPeer>()
    
    private var cancellables: Set<AnyCancellable> = []
    
    fileprivate init(mesh: Mesh, instanceID: InstanceID, endpoint: NWEndpoint, advertisement: PeerAdvertisement) {
        self.mesh = mesh
        self.instanceID = instanceID
        self.endpoint = endpoint
        self.advertisement = advertisement
        
        self.connectionsTo.objectWillChange
            .sink { _ in self.objectWillChange.send() }
            .store(in: &self.cancellables)
        self.connectionsFrom.objectWillChange
            .sink { _ in self.objectWillChange.send() }
            .store(in: &self.cancellables)
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

// MARK: ViewModel implementations

extension Mesh: MeshViewModel {
    var status: MeshStatus {
        var errors = [String]()
        
        for listener in self.localListeners {
            if case .failed(let error) = listener.state {
                // TODO: have map by config
                errors.append("Local listener failed: \(error)")
            }
        }
        
        if errors.count > 0 {
            return .errors(errors)
        } else if self.localListeners.allSatisfy({ $0.state == .ready }) &&
            self.meshListener.state == .ready &&
            self.meshBrowser.state == .ready &&
            self.peerMap[self.myInstanceID] != nil
        {
            return .connected
        } else {
            return .connecting
        }
    }
    
    var peers: Set<Peer> {
        // hide peers until connected
        if case .connected = status {
            return Set(peerMap.values)
        } else {
            return Set()
        }
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
