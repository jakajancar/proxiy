//
//  EchoTests.swift
//  ProxyTests
//
//  Created by Jaka Jancar on 3/2/21.
//

import XCTest
import Network
@testable import Proxiy

class EchoTests: XCTestCase {
    func testEchoConnectionTCP() {
        let finishedExpectation = expectation(description: "finished")
        createEchoConnection(params: .tcp) { echoConn in
            // Hello
            let hello = "hello".data(using: .utf8)
            echoConn.send(content: hello, isComplete: true, completion: .contentProcessed({ error in
                XCTAssertNil(error)
                echoConn.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { (data, ctx, isComplete, error) in
                    XCTAssertNil(error)
                    XCTAssertEqual(data, hello)
                    XCTAssertEqual(ctx?.isFinal, true)
                    XCTAssertEqual(isComplete, false)
                    
                    // World
                    let world = " world".data(using: .utf8)
                    echoConn.send(content: world, isComplete: true, completion: .contentProcessed({ error in
                        XCTAssertNil(error)
                        echoConn.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { (data, ctx, isComplete, error) in
                            XCTAssertNil(error)
                            XCTAssertEqual(data, world)
                            XCTAssertEqual(ctx?.isFinal, true)
                            XCTAssertEqual(isComplete, false)
                            
                            // EOF
                            echoConn.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed({ error in
                                XCTAssertNil(error)
                                echoConn.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { (data, ctx, isComplete, error) in
                                    XCTAssertNil(error)
                                    XCTAssertEqual(data, nil)
                                    XCTAssertEqual(ctx?.isFinal, true)
                                    XCTAssertEqual(isComplete, true)
                                    
                                    finishedExpectation.fulfill()
                                }
                            }))
                        }
                    }))
                }
            }))
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testEchoConnectionUDP() {
        let finishedExpectation = expectation(description: "finished")
        createEchoConnection(params: .udp) { echoConn in
            // Hello
            let hello = "hello".data(using: .utf8)
            echoConn.send(content: hello, isComplete: true, completion: .contentProcessed({ error in
                XCTAssertNil(error)
                echoConn.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { (data, ctx, isComplete, error) in
                    XCTAssertNil(error)
                    XCTAssertEqual(data, hello)
                    XCTAssertEqual(ctx?.isFinal, false)
                    XCTAssertEqual(isComplete, true)
                    
                    // World
                    let world = " world".data(using: .utf8)
                    echoConn.send(content: world, isComplete: true, completion: .contentProcessed({ error in
                        XCTAssertNil(error)
                        echoConn.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { (data, ctx, isComplete, error) in
                            XCTAssertNil(error)
                            XCTAssertEqual(data, world)
                            XCTAssertEqual(ctx?.isFinal, false)
                            XCTAssertEqual(isComplete, true)
                            
                            finishedExpectation.fulfill()
                            
//                            // Empty
//                            // CURRENTLY BORKED AND CLOSES CONNECTION:
//                            // https://developer.apple.com/forums/thread/112917?login=true&page=1#664615022
//                            let empty = "".data(using: .utf8)
//                            echoConn.send(content: empty, isComplete: true, completion: .contentProcessed({ error in
//                                XCTAssertNil(error)
//                                echoConn.receive(minimumIncompleteLength: 0, maximumLength: Int.max) { (data, ctx, isComplete, error) in
//                                    XCTAssertNil(error)
//                                    XCTAssertEqual(data, empty)
//                                    XCTAssertEqual(ctx?.isFinal, false)
//                                    XCTAssertEqual(isComplete, true)
//
//                                    finishedExpectation.fulfill()
//                                }
//                            }))
                        }
                    }))
                }
            }))
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}
