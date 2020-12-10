//
//  ThreadSafetyTests.swift
//  
//
//  Created by Max Obermeier on 24.11.20.
//


import XCTest
import NIO
import Vapor
import Fluent
@testable import Apodini
import Runtime

protocol ForeignKeyProtocol {
    var name: String? { get }
    var type: Any.Type { get }
    var keyType: Any.Type { get }
}

final class ThreadSafetyTests: ApodiniTests {
    struct Greeter: Component {
        @_Request
        var req: Vapor.Request
        
        func handle() -> String {
            req.body.string ?? "World"
        }
    }

    @propertyWrapper
    struct ForeignKey<ID : Hashable>: ForeignKeyProtocol {
        let name: String?
        let type: Any.Type
        var wrappedValue: ID

        var keyType: Any.Type {
            return ID.self
        }

        public init<T : Identifiable>(wrappedValue: ID, _ name: String? = nil, for type: T.Type) where T.ID == ID {
            self.name = name
            self.type = type
            self.wrappedValue = wrappedValue
        }
    }

    struct SomeIdentifiable: Identifiable {
        var id: String
    }

    struct TestStructWithForeignKey {
        @ForeignKey("some", for: SomeIdentifiable.self)
        var key: String = ""
    }

    struct TestClassWithForeignKey {
        @ForeignKey("some", for: SomeIdentifiable.self)
        var key: String = ""
    }

    func testForeignKey() {
        let instance = try! createInstance(of: TestClassWithForeignKey.self) as Any
        let info = try! typeInfo(of: TestClassWithForeignKey.self)
        for property in info.properties {
            if property.type is ForeignKeyProtocol.Type {
                let value = try! property.get(from: instance) as! ForeignKeyProtocol
                print(value.name)
            }
        }
    }
    
    func testRequestInjectableUnlimitedConcurrency() throws {
        let greeter = Greeter()
        var count = 1000
        let countMutex = NSLock()
        
        DispatchQueue.concurrentPerform(iterations: count) { _ in
            let id = randomString(length: 40)
            let request = Request(application: app, collectedBody: ByteBuffer(string: id), on: app.eventLoopGroup.next())
            
            do {
                let response = try request
                    .enterRequestContext(with: greeter) { component in
                        component.handle().encodeResponse(for: request)
                    }
                    .wait()
                let responseData = try XCTUnwrap(response.body.data)
                
                XCTAssert(String(data: responseData, encoding: .utf8) == id)
                
                countMutex.lock()
                count -= 1
                countMutex.unlock()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
        XCTAssertEqual(count, 0)
    }
    
    func testRequestInjectableSingleThreaded() throws {
        let greeter = Greeter()
        var count = 1000
        
        for _ in 0..<count {
            let id = randomString(length: 40)
            let request = Request(application: app, collectedBody: ByteBuffer(string: id), on: app.eventLoopGroup.next())
            
            do {
                let response = try request
                    .enterRequestContext(with: greeter) { component in
                        component.handle().encodeResponse(for: request)
                    }
                    .wait()
                let responseData = try XCTUnwrap(response.body.data)
                
                XCTAssert(String(data: responseData, encoding: .utf8) == id)
                
                count -= 1
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
        XCTAssertEqual(count, 0)
    }
    
    // swiftlint:disable force_unwrapping
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    // swiftlint:enable force_unwrapping
}
