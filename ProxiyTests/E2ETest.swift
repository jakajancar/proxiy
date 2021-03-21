//
//  E2ETest.swift
//  ProxiyTests
//
//  Created by Jaka Jancar on 3/20/21.
//

import XCTest
import Combine
@testable import Proxiy

class E2ETest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    func testPeersSeeEachOther() throws {
        let finishedExpectation = expectation(description: "finished")
        createMeshPair(
            configA: MeshConfig(psk: "psk", acceptInbound: false, listeners: []),
            configB: MeshConfig(psk: "psk", acceptInbound: false, listeners: [])
        ) { (srcMesh, relayMesh) in
            finishedExpectation.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}


func createMeshPair(configA: MeshConfig, configB: MeshConfig, completion: @escaping (Mesh, Mesh) -> Void) {
    let meshA = Mesh(deviceInfo: DeviceInfo(name: "A", machine: "unknown"), config: configA)
    let meshB = Mesh(deviceInfo: DeviceInfo(name: "B", machine: "unknown"), config: configB)
    
    var subscriber: AnyCancellable?
    subscriber = meshA.objectWillChange.merge(with: meshB.objectWillChange)
        .receive(on: DispatchQueue.main) // wait until changed
        .sink { Void in
            switch (meshA.status, meshB.status) {
            case (.errors(let errors), _), (_, .errors(let errors)):
                fatalError("mesh startup failed: \(errors)")
            case (.connected, .connected) where meshA.peers.count == 2 && meshB.peers.count == 2:
                precondition(subscriber != nil)
                subscriber = nil // ensures sub is retained, as well as cancels it on first match
                completion(meshA, meshB)
            default:
                break
            }
        }
}
