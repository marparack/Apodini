//
// Created by Andreas Bauer on 29.12.20.
//

import NIO
import Foundation
import Logging
import ApodiniUtils

struct ValidatingRequest<I: InterfaceExporter, H: Handler>: Request {
    var description: String {
        var request = "Validating Request:\n"
        if let convertible = exporterRequest as? CustomStringConvertible {
            request += convertible.description
        }
        return request
    }
    var debugDescription: String {
        var request = "Validating Request:\n"
        if let convertible = exporterRequest as? CustomDebugStringConvertible {
            request += convertible.debugDescription
        }
        return request
    }

    var endpoint: AnyEndpoint {
        storedEndpoint
    }

    let exporter: I
    let exporterRequest: I.ExporterRequest
    let endpointValidator: EndpointValidator<I, H>
    let storedEndpoint: Endpoint<H>
    let eventLoop: EventLoop
    var remoteAddress: SocketAddress? {
        exporterRequest.remoteAddress
    }
    var information: Set<AnyInformation> {
        exporterRequest.information
    }

    // Must be done in main class, not allowed in extension
    @Boxed internal var parameterLoggingMetadata: Logger.Metadata = ["parameters":.dictionary(.init())]

    var loggingMetadata: Logger.Metadata {
        self.defaultLoggingMetadata
    }

    init(
        for exporter: I,
        with request: I.ExporterRequest,
        using endpointValidator: EndpointValidator<I, H>,
        on endpoint: Endpoint<H>,
        running eventLoop: EventLoop
    ) {
        self.exporter = exporter
        self.exporterRequest = request
        self.endpointValidator = endpointValidator
        self.storedEndpoint = endpoint
        self.eventLoop = eventLoop
    }

    func retrieveParameter<Element: Codable>(_ parameter: Parameter<Element>) throws -> Element {
        let validatedParameter: Element = try endpointValidator.validate(one: parameter.id)
        
        logParameterMetadata(validatedParameter: validatedParameter, parameterID: parameter.id)
        
        return validatedParameter
    }
    
    func retrieveAnyParameter(_ id: UUID) throws -> Any {
        try endpointValidator.validate(one: id)
    }
}
