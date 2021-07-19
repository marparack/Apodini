//                   
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//              

import Apodini
import Vapor

// MARK: AbortError

extension ApodiniError: AbortError {
    public var status: HTTPResponseStatus {
        self.option(for: .httpResponseStatus)
    }
    
    public var reason: String {
        self.standardMessage
    }
    
    public var headers: HTTPHeaders {
        HTTPHeaders(information)
    }
}


// MARK: HTTPResponseStatus Option

extension HTTPResponseStatus: ApodiniErrorCompliantOption {
    public static func `default`(for type: ErrorType) -> HTTPResponseStatus {
        switch type {
        case .badInput:
            return .badRequest
        case .notFound:
            return .notFound
        case .unauthenticated:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .serverError:
            return .internalServerError
        case .notAvailable:
            return .serviceUnavailable
        case .other:
            return .internalServerError
        }
    }
}

extension PropertyOptionKey where PropertyNameSpace == ErrorOptionNameSpace, Option == HTTPResponseStatus {
    static let httpResponseStatus = PropertyOptionKey<ErrorOptionNameSpace, HTTPResponseStatus>()
}

extension AnyPropertyOption where PropertyNameSpace == ErrorOptionNameSpace {
    /// An option that holds the HTTP response status.
    public static func httpResponseStatus(_ code: HTTPResponseStatus) -> AnyPropertyOption<ErrorOptionNameSpace> {
        AnyPropertyOption(key: .httpResponseStatus, value: code)
    }
}