//
//  Request.swift
//  
//
//  Created by Paul Schmiedmayer on 7/12/20.
//
import Foundation
import NIO
import Logging

public protocol Request: CustomStringConvertible, CustomDebugStringConvertible {
    /// Returns a description of the Request.
    /// If the `ExporterRequest` also conforms to `CustomStringConvertible`, its `description`
    /// will be appended.
    var description: String { get }
    /// Returns a debug description of the Request.
    /// If the `ExporterRequest` also conforms to `CustomDebugStringConvertible`, its `debugDescription`
    /// will be appended.
    var debugDescription: String { get }

    var endpoint: AnyEndpoint { get }

    var eventLoop: EventLoop { get }

    var remoteAddress: SocketAddress? { get }
    
    var information: Set<AnyInformation> { get }

    func retrieveParameter<Element: Codable>(_ parameter: Parameter<Element>) throws -> Element
    
    /// Metadata from request
    var loggingMetadata: Logger.Metadata { get }
}

public extension Request {
    var loggingMetadata: Logger.Metadata {
        defaultLoggingMetadata
    }
    
    private var defaultLoggingMetadata: Logger.Metadata {
        [
             /// Name of the endpoint (so the name of the handler class)
             "endpoint": .string("\(self.endpoint.description)"),
             /// Absolut path of the request
             "endpointAbsolutePath": .string("\(self.endpoint.absolutePath.asPathString())"),
             /// If size of the value a parameter is too big -> discard it and insert error message?
             // "@Parameter var name: String = World"
             "endpointParameters": .array(
                self.endpoint.parameters.map { parameter in
                    .string(parameter.description)
                }),
             /// A textual description of the request, most detailed for the RESTExporter
             "request-desciption": .string(self.description),
             /// Set remote address
             "remoteAddress": .string("\(self.remoteAddress?.description ?? "")")
        ]
    }
}
