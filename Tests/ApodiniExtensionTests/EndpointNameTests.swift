//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import XCTApodini
import XCTest
@testable import Apodini
import ApodiniExtension


private struct AddUser: Handler {
    @Parameter var name: String
    
    func handle() async throws -> UUID {
        UUID()
    }
    
    var metadata: AnyHandlerMetadata {
        Operation(.create)
    }
}


private struct GetUser: Handler {
    @Parameter var id: UUID
    
    func handle() async throws -> String {
        "Lukas"
    }
}


private struct ListUsers: Handler {
    func handle() async throws -> [String] {
        ["Lukas", "Paul"]
    }
}


class EndpointNameTests: XCTApodiniTest {
    func testEndpointHandlerTypeNameBasedNameGenerationForOperationTypeCreate() throws {
        let modelBuilder = SemanticModelBuilder(app)
        let visitor = SyntaxTreeVisitor(modelBuilder: modelBuilder)
        AddUser().accept(visitor)
        visitor.finishParsing()
        let endpoint = try XCTUnwrap(modelBuilder.collectedEndpoints.first as? Endpoint<AddUser>)
        
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .camelCase), "user")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .pascalCase), "User")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .snakeCase), "user")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .camelCase), "addUser")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .pascalCase), "AddUser")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .snakeCase), "add_user")
    }
    
    
    func testEndpointHandlerTypeNameBasedNameGenerationForOperationTypeRead() throws {
        let modelBuilder = SemanticModelBuilder(app)
        let visitor = SyntaxTreeVisitor(modelBuilder: modelBuilder)
        GetUser().accept(visitor)
        visitor.finishParsing()
        let endpoint = try XCTUnwrap(modelBuilder.collectedEndpoints.first as? Endpoint<GetUser>)
        
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .camelCase), "user")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .pascalCase), "User")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .snakeCase), "user")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .camelCase), "getUser")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .pascalCase), "GetUser")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .snakeCase), "get_user")
    }
    
    
    func testMetadataBasedNameGeneration() throws {
        let modelBuilder = SemanticModelBuilder(app)
        let visitor = SyntaxTreeVisitor(modelBuilder: modelBuilder)
        Text("")
            .endpointName(noun: "RetryFailedTransactions", verb: "RetryFailedTransactions")
            .accept(visitor)
        visitor.finishParsing()
        let endpoint = try XCTUnwrap(modelBuilder.collectedEndpoints.first as? Endpoint<Text>)
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .camelCase), "retryFailedTransactions")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .pascalCase), "RetryFailedTransactions")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .snakeCase), "retry_failed_transactions")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .camelCase), "getRetryFailedTransactions")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .pascalCase), "GetRetryFailedTransactions")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .snakeCase), "get_retry_failed_transactions")
    }
    
    
    func testMetadataBasedFixedEndpointName() throws {
        let modelBuilder = SemanticModelBuilder(app)
        let visitor = SyntaxTreeVisitor(modelBuilder: modelBuilder)
        Text("")
            .endpointName(fixed: "eNdPoInTnAmEThAtDoEsNTmaKeALOtoFsEnSe")
            .accept(visitor)
        visitor.finishParsing()
        let endpoint = try XCTUnwrap(modelBuilder.collectedEndpoints.first as? Endpoint<Text>)
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .camelCase), "eNdPoInTnAmEThAtDoEsNTmaKeALOtoFsEnSe")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .pascalCase), "eNdPoInTnAmEThAtDoEsNTmaKeALOtoFsEnSe")
        XCTAssertEqual(endpoint.getEndointName(.noun, format: .snakeCase), "eNdPoInTnAmEThAtDoEsNTmaKeALOtoFsEnSe")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .camelCase), "eNdPoInTnAmEThAtDoEsNTmaKeALOtoFsEnSe")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .pascalCase), "eNdPoInTnAmEThAtDoEsNTmaKeALOtoFsEnSe")
        XCTAssertEqual(endpoint.getEndointName(.verb, format: .snakeCase), "eNdPoInTnAmEThAtDoEsNTmaKeALOtoFsEnSe")
    }
}
