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

class Mesh {
    private static let kBonjourServiceType: String = "_jjproxy._tcp"
    // BUG: https://developer.apple.com/forums/thread/673143
    private static let kUseTLSBetweenPeers: Bool = false
    
    /// Random UUID generated at startup.
    private let myInstanceID: InstanceID = UUID().uuidString
    
    @Published var deviceInfo: DeviceInfo
    
    /// User-defined configuration.
    @Published var config: Config {
        didSet {
            self.psk = config.createSymmetricKey()
            self.meshListener.service = self.createService()
            self.refreshLocalListeners()
        }
    }
    
    /// `SymmetricKey` build from the configuration.
    private var psk: SymmetricKey {
        didSet {
            for result in self.meshBrowser.browseResults {
                self.updatePeer(result: result)
            }
        }
    }
    
    /// Bonjour listener and service advertiser.
    private let meshListener: NWListener
    
    /// Bonjour service browser.
    private let meshBrowser: NWBrowser
    
    /// Peers indexed by instance, so that Bonjour updates can be easily applied and inbound connections easily tracked.
    @Published fileprivate var peerMap: [InstanceID : Peer] = [:]
    
    private var localListeners: [Config.Listener : NWListener] = [:]
    
    init(deviceInfo: DeviceInfo, config: Config) {
        self.deviceInfo = deviceInfo
        self.config = config
        self.psk = config.createSymmetricKey()
        
        // Init listener
        do {
            let tcpOpts = NWProtocolTCP.Options()

            let params = NWParameters.init(
                tls: Mesh.kUseTLSBetweenPeers ? Self.tlsOptions(psk: psk) : nil,
                tcp: tcpOpts)
            params.includePeerToPeer = true
                        
            let listener = try! NWListener(using: params)
            listener.stateUpdateHandler = { state in
                switch state {
                case .failed(_):
                    break // todo
                case .cancelled:
                    break // todo
                default:
                    break
                }
            }
            
            self.meshListener = listener
        }
        
        // Init browser
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let browser = NWBrowser.init(
                for: .bonjourWithTXTRecord(type: Mesh.kBonjourServiceType, domain: nil),
                using: params)
            
            self.meshBrowser = browser
        }
        
        self.refreshLocalListeners() // TODO: dedup
        
        self.meshListener.service = self.createService()
        self.meshListener.newConnectionHandler = self.handleConnectionFromPeer
        self.meshListener.start(queue: DispatchQueue.main)
        
        self.meshBrowser.browseResultsChangedHandler = self.bonjourChanged(results:changes:)
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
    
    private func createService() -> NWListener.Service {
        NWListener.Service(
            name: self.myInstanceID,
            type: Mesh.kBonjourServiceType,
            domain: nil,
            txtRecord: PeerAdvertisement(
                deviceInfo: self.deviceInfo,
                allowsInbound: self.config.allowInbound
            ).toTxtRecord(using: self.psk))
    }
    
//    func forceCancel() {
//        self.cancelled = true
//        for result in self.meshBrowser.browseResults {
//            self.updatePeer(result: result)
//        }
//    }
//
//    deinit {
//        // force cancel peers
//    }
    
    private func updatePeer(result: NWBrowser.Result) {
        if case .service(name: let instanceID, type: _, domain: _, interface: _) = result.endpoint {
            if case .bonjour(let txt) = result.metadata {
                if let advertisement = PeerAdvertisement.fromTxtRecord(txt, using: self.psk) {
                    if let existingPeer = self.peerMap[instanceID] {
                        // Update existing
                        existingPeer.advertisement = advertisement
                    } else {
                        // Add new
                        self.peerMap[instanceID] = Peer(
                            instanceID: instanceID,
                            endpoint: result.endpoint,
                            advertisement: advertisement)
                    }
                } else {
                    // Other network
                    self.removePeer(result: result)
                }
            } else {
                fatalError("non-Bonjour metadata: \(result.metadata)")
            }
        } else {
            fatalError("non-service endpoint: \(result.endpoint)")
        }
    }
    
    private func removePeer(result: NWBrowser.Result) {
        if case .service(name: let instanceID, type: _, domain: _, interface: _) = result.endpoint {
            if let peer = self.peerMap.removeValue(forKey: instanceID) {
                peer.forceCancel()
            }
        } else {
            fatalError("non-service endpoint?")
        }
    }
    
    private func bonjourChanged(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let new):
                self.updatePeer(result: new)
            case .removed(let old):
                self.removePeer(result: old)
            case .changed(old: let old, new: let new, flags: _):
                assert(old.endpoint == new.endpoint)
                self.updatePeer(result: new)
            default:
                break
            }
        }
    }
    
    private func selectPeer(via: Config.Via) -> Peer? {
        let matching = self.peerMap.values.filter { (peer) -> Bool in
//            peer.instanceID != self.myInstanceID &&
                peer.advertisement.allowsInbound &&
                    (via.nameFilter != nil ? via.nameFilter == peer.deviceInfo.name : true)
        }
        return matching.randomElement()
    }
    
    private func refreshLocalListeners() {
        print("refreshing local listeners")
        // Compute diff
        let needed = Set(self.config.listeners)
        let existing = Set(self.localListeners.keys)
        let toRemove = existing.subtracting(needed)
        let toAdd = needed.subtracting(existing)
        print("Removing \(toRemove), adding \(toAdd)")
        
        // Remove obsolete listeners
        for config in toRemove {
            self.localListeners[config]!.cancel()
            self.localListeners.removeValue(forKey: config)
        }
        
        // Add missing listeners
        for config in toAdd {
            let tcpOpts = NWProtocolTCP.Options()
            tcpOpts.noDelay = true
            
            let udpOpts = NWProtocolUDP.Options()
            
            let listenerParams: NWParameters
            let newConnectionHandler: (NWConnection) -> Void
            
            switch config.connectInstructions {
            case .Tcp(remoteHost: let remoteHost, remotePort: let remotePort):
                listenerParams = NWParameters(tls: nil, tcp: tcpOpts)
            case .Udp(remoteHost: let remoteHost, remotePort: let remotePort):
                listenerParams = NWParameters(dtls: nil, udp: udpOpts)
            case .Socks:
                listenerParams = NWParameters(tls: nil, tcp: tcpOpts)
            }
            
            listenerParams.requiredInterfaceType = .loopback
            listenerParams.allowLocalEndpointReuse = true // TIME_WAIT doesn't seem to be applied, but just in case
            
            let listener = try! NWListener(using: listenerParams, on: config.localPort)
            listener.stateUpdateHandler = { state in
//                    print("local listener state = \(state)")
            }
            listener.newConnectionHandler = { conn in
                if let targetPeer = self.selectPeer(via: config.via) {
                    let targetTCPOpts = NWProtocolTCP.Options()
                    targetTCPOpts.noDelay = true

                    let targetParams = NWParameters.init(
                        tls: Mesh.kUseTLSBetweenPeers ? Self.tlsOptions(psk: self.psk) : nil,
                        tcp: tcpOpts)
                    
                    let targetConn = NWConnection(to: targetPeer.endpoint, using: targetParams)
                    targetPeer.track(connectionToPeer: targetConn)
                    
                    conn.stateUpdateHandler = { [weak conn, weak targetConn] state in
                        switch state {
                        case .waiting(_), .failed(_):
                            print("local connection has failed")
                            conn?.cancel()
                        case .cancelled:
                            print("canceling connection to peer because local connection was cancelled")
                            targetConn?.cancel()
                        default:
                            break
                        }
                    }
                    
                    conn.start(queue: DispatchQueue.main)
                    targetConn.start(queue: DispatchQueue.main)
                    
                    print("sending client request")
                    let clientRequest = ClientRequest(instanceID: self.myInstanceID, instructions: config.connectInstructions)
                    targetConn.send(clientRequest: clientRequest) { error in
                        print("sent client request")
                        guard error == nil else { return }
                        conn.transcieve(between: targetConn) { error in
                            print("transcieve between local and remote peer completed")
                            conn.cancel()
                            targetConn.cancel()
                        }
                    }

                } else {
                    logger.log("no matching peer for connection to listener")
                    conn.cancel()
                }
            }

            self.localListeners[config] = listener
            listener.start(queue: DispatchQueue.main)
        }
    }

    private func handleConnectionFromPeer(conn: NWConnection) {
        conn.start(queue: DispatchQueue.main)
        
        conn.receiveClientRequest { (clientRequest, error) in
            guard error == nil else { return }
            guard let clientRequest = clientRequest else { return }
            
            guard let peer = self.peerMap[clientRequest.instanceID] else {
                logger.log("got request from peer not in peerMap")
                return
            }
            peer.track(connectionFromPeer: conn)
            
            let tcpOpts = NWProtocolTCP.Options()
            tcpOpts.noDelay = true
            
            let udpOpts = NWProtocolUDP.Options()

            switch clientRequest.instructions {
            case .Tcp(remoteHost: let remoteHost, remotePort: let remotePort):
                let params = NWParameters(tls: nil, tcp: tcpOpts)
                let targetConn = NWConnection(host: .name(remoteHost, nil), port: remotePort, using: params)
                targetConn.transcieve(between: conn) { error in
                    //
                }
                targetConn.start(queue: DispatchQueue.main)
            case .Udp(remoteHost: let remoteHost, remotePort: let remotePort):
                let params = NWParameters(dtls: nil, udp: udpOpts)
                let targetConn = NWConnection(host: .name(remoteHost, nil), port: remotePort, using: params)
                targetConn.transcieve(between: conn) { error in
                    //
                }
                targetConn.start(queue: DispatchQueue.main)
                break
            case .Socks:
                print("got request, will handle socks")
                conn.receiveAndHandleSocks { error in
                    print("socks handling finished")
                    if case .proto(let str) = error {
                        logger.log("SOCKS protocol error: \(str)")
                    }
                    conn.cancel()
                }
            }
        }
    }
}

class Peer {
    fileprivate let instanceID: InstanceID
    fileprivate let endpoint: NWEndpoint
    fileprivate var advertisement: PeerAdvertisement
    
    @Published private var connectionsTo: Set<NWConnection> = [] // does not include local part
    @Published private var connectionsFrom: Set<NWConnection> = [] // does not include internet part
    
    fileprivate init(instanceID: InstanceID, endpoint: NWEndpoint, advertisement: PeerAdvertisement) {
        self.instanceID = instanceID
        self.endpoint = endpoint
        self.advertisement = advertisement
    }
    
    // Tracks the connection and sets it's state update handler.
    private func track(connection conn: NWConnection, inSet set: ReferenceWritableKeyPath<Peer, Set<NWConnection>>) {
        self[keyPath: set].insert(conn)
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            switch state {
            case .waiting(_), .failed(_):
                print("tracked connection failed")
                conn?.cancel()
            case .cancelled:
                print("tracked connection cancelled")
                if let self = self, let conn = conn {
                    self[keyPath: set].remove(conn)
                }
            default:
                break
            }
        }
        
    }
    
    fileprivate func track(connectionToPeer conn: NWConnection) {
        self.track(connection: conn, inSet: \.connectionsTo)
    }
    
    fileprivate func track(connectionFromPeer conn: NWConnection) {
        self.track(connection: conn, inSet: \.connectionsFrom)
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

private extension Config {
    func createSymmetricKey() -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: self.psk.data(using: .utf8)!))
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
    var deviceInfo: DeviceInfo {
        self.advertisement.deviceInfo
    }
    
    var connectionsFromCount: Int {
        self.connectionsFrom.count
    }
    
    var connectionsToCount: Int {
        self.connectionsTo.count
    }
    
    var bytesPerSec: Int64 { 0 }
}
