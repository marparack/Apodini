//                   
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//              

@testable import Apodini
import ApodiniREST
import XCTApodini
import XCTVapor
import XCTest

import _NIOConcurrency

final class ConnectionTests: ApodiniTests {
    let endMessage = "End"
    let openMessage = "Open"
    
    struct TestHandler: Handler {
        @Apodini.Environment(\.connection)
        var connection: Connection
        
        var endMessage: String
        var openMessage: String
        
        func handle() -> Apodini.Response<String> {
            switch connection.state {
            case .open:
                return .send(openMessage)
            case .end:
                return .final(endMessage)
            }
        }
    }
    
    func testDefaultConnectionEnvironment() throws {
        var testHandler = TestHandler(endMessage: endMessage, openMessage: openMessage).inject(app: app)
        activate(&testHandler)
        
        let endpoint = testHandler.mockEndpoint(app: app)
        
        let exporter = MockExporter<String>()
        let context = endpoint.createConnectionContext(for: exporter)
        
        try XCTCheckResponse(
            context.handle(request: "Example Request", eventLoop: app.eventLoopGroup.next()),
            content: endMessage,
            connectionEffect: .close
        )
    }
    
    func testConnectionInjection() throws {
        let mockRequest = MockRequest.createRequest(running: app.eventLoopGroup.next(), queuedParameters: .none)
        var testHandler = TestHandler(endMessage: endMessage, openMessage: openMessage).inject(app: app)
        activate(&testHandler)
        
        var connection = Connection(state: .open, request: mockRequest)
        _ = try connection.enterConnectionContext(with: testHandler) { handler in
            try XCTCheckResponse(
                handler.handle(),
                content: openMessage,
                connectionEffect: .open
            )
        }
        
        connection.state = .end
        _ = try connection.enterConnectionContext(with: testHandler) { handler in
            try XCTCheckResponse(
                handler.handle(),
                content: endMessage,
                connectionEffect: .close
            )
        }
    }

    func testConnectionRemoteAddress() throws {
        struct TestHandler: Handler {
            @Apodini.Environment(\.connection)
            var connection: Connection

            func handle() -> String {
                connection.remoteAddress?.description ?? "no remote"
            }
        }
        
        struct TestWebService: WebService {
            var content: some Component {
                TestHandler()
            }

            var configuration: Configuration {
                REST()
            }
        }

        TestWebService().start(app: app)

        try app.vapor.app.testable(method: .running).test(.GET, "/v1/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssert(res.body.string.contains("127.0.0.1:8080"))
        }
    }
}
