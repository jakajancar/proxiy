//
//  NWError+CodableTest.swift
//  ProxyTests
//
//  Created by Jaka Jancar on 3/9/21.
//

import XCTest
import Network
@testable import Proxiy

class NWErrorCodableTests: XCTestCase {
    func testPosix() {
        let original = NWError.posix(.ELOOP)
        let encoded = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(NWError.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testDns() {
        let original = NWError.dns(1234)
        let encoded = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(NWError.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testTls() {
        let original = NWError.tls(-1234)
        let encoded = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(NWError.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }
}
