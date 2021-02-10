//
//  Created by Lorena Schlesinger on 1/15/21.
//

import XCTest
@_implementationOnly import Runtime

@testable import Apodini

class EnrichedInfoTests: ApodiniTests {
    func testCardinalityIsEquatable() throws {
        let keyType = EnrichedInfo(
            typeInfo: try typeInfo(of: String.self),
            propertyInfo: nil
        )
        let valueType = EnrichedInfo(
            typeInfo: try typeInfo(of: Int.self),
            propertyInfo: nil
        )
        
        XCTAssertEqual(
            EnrichedInfo.Cardinality.zeroToOne,
            EnrichedInfo.Cardinality.zeroToOne
        )
        XCTAssertEqual(
            EnrichedInfo.Cardinality.exactlyOne,
            EnrichedInfo.Cardinality.exactlyOne
        )
        XCTAssertEqual(
            EnrichedInfo.Cardinality.zeroToMany(.array),
            EnrichedInfo.Cardinality.zeroToMany(.array)
        )
        XCTAssertEqual(
            EnrichedInfo.Cardinality.zeroToMany(
                .dictionary(
                    key: keyType,
                    value: valueType
                )
            ),
            EnrichedInfo.Cardinality.zeroToMany(
                .dictionary(
                    key: keyType,
                    value: valueType
                )
            )
        )
        XCTAssertNotEqual(
            EnrichedInfo.Cardinality.zeroToMany(
                .array
            ),
            EnrichedInfo.Cardinality.zeroToMany(
                .dictionary(
                    key: keyType,
                    value: valueType
                )
            )
        )
        XCTAssertNotEqual(
            EnrichedInfo.Cardinality.zeroToOne,
            EnrichedInfo.Cardinality.exactlyOne
        )
        XCTAssertNotEqual(
            EnrichedInfo.Cardinality.zeroToOne,
            EnrichedInfo.Cardinality.zeroToMany(.array)
        )
        XCTAssertNotEqual(
            EnrichedInfo.Cardinality.exactlyOne,
            EnrichedInfo.Cardinality.zeroToMany(.array)
        )
    }

    func testCollectionContextIsEquatable() throws {
        let keyType = EnrichedInfo(
            typeInfo: try typeInfo(of: String.self),
            propertyInfo: nil
        )
        let valueType = EnrichedInfo(
            typeInfo: try typeInfo(of: Int.self),
            propertyInfo: nil
        )
        let valueType1 = EnrichedInfo(
            typeInfo: try typeInfo(of: String.self),
            propertyInfo: nil
        )
        
        XCTAssertEqual(
            EnrichedInfo.CollectionContext.array,
            EnrichedInfo.CollectionContext.array
        )
        XCTAssertEqual(
            EnrichedInfo.CollectionContext.dictionary(key: keyType, value: valueType),
            EnrichedInfo.CollectionContext.dictionary(key: keyType, value: valueType)
        )
        XCTAssertNotEqual(
            EnrichedInfo.CollectionContext.dictionary(key: keyType, value: valueType),
            EnrichedInfo.CollectionContext.array
        )
        XCTAssertNotEqual(
            EnrichedInfo.CollectionContext.dictionary(key: keyType, value: valueType),
            EnrichedInfo.CollectionContext.dictionary(key: keyType, value: valueType1)
        )
    }

    func testEnrichedInfoIsEquatable() throws {
        let stringType = EnrichedInfo(
            typeInfo: try typeInfo(of: String.self),
            propertyInfo: nil
        )
        let stringType1 = EnrichedInfo(
            typeInfo: try typeInfo(of: String.self),
            propertyInfo: nil
        )
        let intType = EnrichedInfo(
            typeInfo: try typeInfo(of: Int.self),
            propertyInfo: nil
        )
        let complexReflectedType = try typeInfo(of: Array<Int>.self)
        let complexReflectedTypeProperty = try typeInfo(of: complexReflectedType.properties[0].type)
        let complexTypePropertyInfo = EnrichedInfo(
            typeInfo: complexReflectedTypeProperty,
            propertyInfo: .init(
                name: complexReflectedType.properties[0].name,
                offset: 0
            ),
            cardinality: .exactlyOne
        )
        let complexTypePropertyInfo1 = EnrichedInfo(
            typeInfo: complexReflectedTypeProperty,
            propertyInfo: .init(
                name: "",
                offset: 0
            ),
            cardinality: .exactlyOne
        )
        let complexTypePropertyInfo2 = EnrichedInfo(
            typeInfo: complexReflectedTypeProperty,
            propertyInfo: .init(
                name: complexReflectedType.properties[0].name,
                offset: 1
            ),
            cardinality: .exactlyOne
        )
        let complexTypePropertyInfo3 = EnrichedInfo(
            typeInfo: complexReflectedTypeProperty,
            propertyInfo: .init(
                name: complexReflectedType.properties[0].name,
                offset: 0
            ),
            cardinality: .zeroToOne
        )
        
        XCTAssertEqual(stringType, stringType1)
        XCTAssertNotEqual(stringType, intType)
        XCTAssertNotEqual(complexTypePropertyInfo, stringType)
        XCTAssertEqual(complexTypePropertyInfo, complexTypePropertyInfo)
        XCTAssertNotEqual(complexTypePropertyInfo, complexTypePropertyInfo1)
        XCTAssertNotEqual(complexTypePropertyInfo, complexTypePropertyInfo2)
        XCTAssertNotEqual(complexTypePropertyInfo, complexTypePropertyInfo3)
    }
}