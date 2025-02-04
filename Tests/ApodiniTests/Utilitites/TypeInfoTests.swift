//                   
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//              

import XCTest
@testable import Apodini
import ApodiniUtils

class TypeInfoTests: ApodiniTests {
    func testIsOptional() {
        /// A custom type
        struct Test {}

        XCTAssertEqual(isOptional(String.self), false)
        XCTAssertEqual(isOptional(Int.self), false)
        XCTAssertEqual(isOptional(Test.self), false)
        XCTAssertEqual(isOptional(Optional<Test>.self), true)
        XCTAssertEqual(isOptional(String?.self), true)
        XCTAssertEqual(isOptional(String??.self), true)
        XCTAssertEqual(isOptional(String???.self), true)
        XCTAssertEqual(isOptional(Never.self), false)
        
        // A case that should throw an error in isOptional
        XCTAssertEqual(isOptional((() -> Void).self), false)
    }

    func testIsEnum() {
        /// A custom type
        enum Test {
            case unit
            case integration
            case system
        }

        XCTAssertEqual(isEnum(Test.self), true)
        XCTAssertEqual(isEnum(Int.self), false)
        XCTAssertEqual(isEnum(Optional<Test>.self), false)
        XCTAssertEqual(isEnum(String?.self), false)
        XCTAssertEqual(isEnum(Never.self), true)

        // A case that should throw an error in isEnum
        XCTAssertEqual(isEnum((() -> Void).self), false)
    }
    
    func testDescription() {
        let parameter = Parameter<String>()
        XCTAssertEqual(ApodiniUtils.mangledName(of: type(of: parameter)), "Parameter")
        
        let array = ["Paul"]
        XCTAssertEqual(ApodiniUtils.mangledName(of: type(of: array)), "Array")
        
        let string = "Paul"
        XCTAssertEqual(ApodiniUtils.mangledName(of: type(of: string)), "String")
        
        XCTAssertEqual(ApodiniUtils.mangledName(of: (() -> Void).self), "() -> ()")
        XCTAssertEqual(ApodiniUtils.mangledName(of: ((String) -> (Int)).self), "(String) -> Int")
    }
}
