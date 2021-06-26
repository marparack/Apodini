//
// Created by Andreas Bauer on 23.05.21.
//

@testable import Apodini
@testable import ApodiniExtension
import XCTest
import XCTApodini

final class EmptyMetadataTests: ApodiniTests {
    func testEmptyMetadataValue() {
        XCTAssertRuntimeFailure(EmptyHandlerMetadata().value)
        XCTAssertRuntimeFailure(EmptyComponentOnlyMetadata().value)
        XCTAssertRuntimeFailure(EmptyWebServiceMetadata().value)
        XCTAssertRuntimeFailure(EmptyComponentMetadata().value)
        XCTAssertRuntimeFailure(EmptyContentMetadata().value)
    }
}
