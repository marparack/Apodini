//
// Created by Andreas Bauer on 29.12.20.
//

import NIO
import Foundation
import Logging

class ValidatingRequest<I: InterfaceExporter, H: Handler>: Request {
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
    
    private var wrappedLoggingMetadata: Logger.Metadata = [:]
    // kann auch weitergespinnt werden, zB. loggingMetadata from exporterRequest
    // shifte es soweit "runter" bis der Typ bekannt ist
    var loggingMetadata: Logger.Metadata {
        get {
            wrappedLoggingMetadata.isEmpty ?
                defaultLoggingMetadata
                : wrappedLoggingMetadata
        }
        set {
            wrappedLoggingMetadata = newValue
        }
        
        //return self.defaultLoggingMetadata.merging(["test": "test"]) { (_, new) in new }
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
        
        logParameterMetadata(parameter: validatedParameter, parameterID: parameter.id)
        
        return validatedParameter
    }
    
    func retrieveAnyParameter(_ id: UUID) throws -> Any {
        try endpointValidator.validate(one: id)
    }
}

extension ValidatingRequest {
    private var defaultLoggingMetadata: Logger.Metadata {
        [
            /// Identifies the current logger instance
            "logger-uuid" : .string("\(UUID())"),
            /// Name of the endpoint (so the name of the handler class)
            "endpoint": .string("\(endpoint.description)"),
            /// Absolut path of the request
            "endpointAbsolutePath": .string("\(endpoint.absolutePath.asPathString())"),
            /// Empty parameter dictionary since property is immutable
            "parameters": .dictionary([:]),
            /// A textual description of the request, most detailed for the RESTExporter
            "request-desciption": .string(description.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)),
            /// Set remote address
            "remoteAddress": .string("\(remoteAddress?.description ?? "")"),
            /// Exporter type, full name would be 'ApodiniREST.RESTInterfaceExporter', we are only interested in the name after the point
            "exporter": .string(String(describing: exporter).components(separatedBy: ".")[1]),
            /// Static parameter namespace
            "exporterParameterNamespace": .string(I.parameterNamespace.map({$0.description}).joined(separator: ", "))
        ].merging(exporterRequest.loggingMetadata) { (_, new) in new }
    }
    
    /// Default `JSONEncoder`that is used for parameter encoding
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]    // maybe .withoutEscapingSlashes? (maybe interferes with kibana?)
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+inf", negativeInfinity: "-inf", nan: "NaN")
        
        return encoder
    }
    
    /// Encode the parameters to JSON and save them in the `loggingMetadata` computed variable
    private func logParameterMetadata<Element: Codable>(parameter: Element, parameterID: UUID) {
        do {
            guard let encodedParameterString = String(data: try jsonEncoder.encode(parameter), encoding: .utf8) else {
                fatalError("Logging of parameters failed - Encoding failed")
            }
            
            updateParameterLoggingMetadata(parameterID: parameterID, parameterJSONEncodedValue: encodedParameterString)
        } catch {
            fatalError("Logging of parameters failed")
        }
    }
    
    /// Update paremeter logging metadata in the `loggingMetadata` computed variable
    private func updateParameterLoggingMetadata(parameterID: UUID, parameterJSONEncodedValue: String) {
        switch loggingMetadata["parameters"] {
        case .dictionary(var parameterDictionary):
            parameterDictionary[getParameterName(ID: parameterID)] = .string(parameterJSONEncodedValue)
            loggingMetadata["parameters"] = .dictionary(parameterDictionary)
        default:
            fatalError("Parameter metadata value is not a dictionary!")
        }
    }
    
    /// Match parameter UUID to name of parameter
    private func getParameterName(ID: UUID) -> String {
        guard let parameterName = endpoint.parameters.filter({ $0.id == ID }).first?.name else {
            fatalError("Logging of parameters failed - Parameter doesn't exist or has no name")
        }
        
        return parameterName
    }
}
