//                   
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//              

import XCTApodini
import ApodiniHTTP
@testable import Apodini
import XCTApodiniNetworking
import Foundation


class EndToEndTests: XCTApodiniTest {
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        configuration.configure(app)
        
        let visitor = SyntaxTreeVisitor(modelBuilder: SemanticModelBuilder(app))
        content.accept(visitor)
        visitor.finishParsing()
    }
    
    
    struct Greeter: Handler {
        @Parameter(.http(.path)) var name: String
        
        @Parameter(.http(.query)) var greeting: String?

        func handle() -> String {
            "\(greeting ?? "Hello"), \(name)!"
        }
    }
    
    struct BlobGreeter: Handler {
        @Parameter(.http(.path)) var name: String
        
        @Parameter(.http(.query)) var greeting: String?
        
        
        var metadata: Metadata {
            Pattern(.requestResponse)
        }
        
        func handle() -> Apodini.Response<Blob> {
            Response.send(
                Blob(Data("\(greeting ?? "Hello"), \(name)!".utf8), type: .text(.plain)),
                information: [AnyHTTPInformation(key: "Test", rawValue: "Test")]
            )
        }
    }

    class FakeTimer: Apodini.ObservableObject {
        @Apodini.Published private var _trigger = true
        
        init() {
            print("FakeTimer.init")
        }
        
        func secondPassed() {
            _trigger.toggle()
        }
        
        deinit {
            print("FakeTimer.deinit")
        }
    }


    struct Rocket: Handler {
        @Parameter(.http(.query), .mutability(.constant)) var start: Int = 10
        
        @State var counter = -1
        
        @ObservedObject var timer = FakeTimer()
        
        func handle() -> Apodini.Response<Blob> {
            timer.secondPassed()
            counter += 1
            
            if counter == start {
                return .final(Blob("🚀🚀🚀 Launch !!! 🚀🚀🚀\n".data(using: .utf8)!, type: .text(.plain)))
            } else {
                return .send(Blob("\(start - counter)...\n".data(using: .utf8)!, type: .text(.plain)))
            }
        }
        
        
        var metadata: AnyHandlerMetadata {
            Pattern(.serviceSideStream)
        }
    }

    struct ClientStreamingGreeter: Handler {
        @Parameter(.http(.query)) var country: String?
        
        @Apodini.Environment(\.connection) var connection
        
        @State var list: [String] = []
        
        func handle() -> Apodini.Response<String> {
            switch connection.state {
            case .open:
                list.append(country ?? "the World")
                return .nothing
            case .end, .close:
                var response = "Hello, " + list[0..<list.count - 1].joined(separator: ", ")
                if let last = list.last {
                    response += " and " + last
                } else {
                    response += "everyone"
                }
                return .final(response + "!")
            }
        }
        
        var metadata: AnyHandlerMetadata {
            Pattern(.clientSideStream)
        }
    }

    struct BidirectionalStreamingGreeter: Handler {
        @Parameter(.http(.query)) var country: String?
        
        @Apodini.Environment(\.connection) var connection
        
        func handle() -> Apodini.Response<String> {
            switch connection.state {
            case .open:
                return .send("Hello, \(country ?? "World")!")
            case .end, .close:
                return .end
            }
        }
        
        var metadata: AnyHandlerMetadata {
            Pattern(.bidirectionalStream)
        }
    }

    var configuration: Configuration {
        HTTP()
    }

    @ComponentBuilder
    var content: some Component {
        Group("rr") {
            Greeter()
        }
        Group("ss") {
            Rocket()
        }
        Group("cs") {
            ClientStreamingGreeter()
        }
        Group("bs") {
            BidirectionalStreamingGreeter()
        }
        Group("blob") {
            BlobGreeter()
        }
    }

    func testRequestResponsePattern() throws {
        try app.testable().test(.GET, "/rr/Paul") { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(try response.bodyStorage.getFullBodyData(decodedAs: String.self, using: JSONDecoder()), "Hello, Paul!")
        }
        
        try app.testable().test(.GET, "/rr/Andi?greeting=Wuzzup") { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(try response.bodyStorage.getFullBodyData(decodedAs: String.self, using: JSONDecoder()), "Wuzzup, Andi!")
        }
    }
    
    func testServiceSideStreamingPattern() throws {
        try app.testable([.actualRequests]).test(
            version: .http1_1,
            .GET,
            "/ss?start=10",
            expectedBodyType: .stream,
            responseEnd: { response in
                XCTAssertEqual(response.status, .ok)
                let responseStream = try XCTUnwrap(response.bodyStorage.stream)
                XCTAssert(responseStream.isClosed)
                // We want to get rid of leading and trailing newlines since that would mess up the line splitting
                let responseText = try XCTUnwrap(response.bodyStorage.readNewDataAsString()).trimmingLeadingAndTrailingWhitespace()
                XCTAssertEqual(responseText.split(separator: "\n"), [
                    "10...",
                    "9...",
                    "8...",
                    "7...",
                    "6...",
                    "5...",
                    "4...",
                    "3...",
                    "2...",
                    "1...",
                    "🚀🚀🚀 Launch !!! 🚀🚀🚀"
                ])
            }
        )
    }
    
    func testClientSideStreamingPattern() throws {
        let body = [
            [
                "query": [
                    "country": "Germany"
                ]
            ],
            [
                "query": [
                    "country": "Taiwan"
                ]
            ],
            [String: [String: String]]()
        ]
        
        try app.testable().test(.GET, "/cs", body: .init(data: JSONEncoder().encode(body))) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(
                try! response.bodyStorage.getFullBodyData(decodedAs: String.self, using: JSONDecoder()),
                "Hello, Germany, Taiwan and the World!"
            )
        }
    }
    
    func testBidirectionalStreamingPattern() throws {
        let body = [
            [
                "query": [
                    "country": "Germany"
                ]
            ],
            [
                "query": [
                    "country": "Taiwan"
                ]
            ],
            [String: [String: String]]()
        ]
        
        try app.testable().test(.GET, "/bs", body: JSONEncoder().encodeAsByteBuffer(body, allocator: .init())) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(try response.bodyStorage.getFullBodyData(decodedAs: [String].self, using: JSONDecoder()), [
                "Hello, Germany!",
                "Hello, Taiwan!",
                "Hello, World!"
            ])
        }
    }
    
    func testBlob() throws {
        try app.testable().test(.GET, "/blob/Paul") { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.bodyStorage.readNewDataAsString(), "Hello, Paul!")
            XCTAssertEqual(response.headers["Content-Type"].first, HTTPMediaType.text(.plain, charset: .utf8).encodeToHTTPHeaderFieldValue())
            XCTAssertEqual(response.headers["Test"].first, "Test")
        }
        
        try app.testable().test(.GET, "/blob/Andi?greeting=Wuzzup") { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.bodyStorage.readNewDataAsString(), "Wuzzup, Andi!")
            XCTAssertEqual(response.headers["Content-Type"].first, HTTPMediaType.text(.plain, charset: .utf8).encodeToHTTPHeaderFieldValue())
            XCTAssertEqual(response.headers["Test"].first, "Test")
        }
    }
}
