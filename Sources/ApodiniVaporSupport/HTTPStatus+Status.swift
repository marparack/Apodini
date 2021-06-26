//
//  HTTPStatus+Status.swift
//
//
//  Created by Paul Schmiedmayer on 5/26/21.
//

import Apodini
import ApodiniExtension
import Vapor


extension Vapor.HTTPStatus {
    /// Creates a `Vapor``HTTPStatus` based on an `Apodini` `Status`.
    /// - Parameter status: The `Apodini` `Status` that should be transformed in a `Vapor``HTTPStatus`
    public init(_ status: ApodiniExtension.Status) {
        switch status {
        case .ok:
            self = .ok
        case .created:
            self = .created
        case .noContent:
            self = .noContent
        case .redirect:
            self = .seeOther
        }
    }
}
