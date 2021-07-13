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

    // Since no stored properties allowed in extensions
    // Need for this variable to set the parameters logging metadata
    private var wrappedParameterLoggingMetadata: Logger.Metadata = [:]

    var loggingMetadata: Logger.Metadata {
        defaultLoggingMetadata
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

extension ValidatingRequest {
    private var defaultLoggingMetadata: Logger.Metadata {
        [
            /// A textual description of the request, most detailed for the RESTExporter
            "request-desciption": .string(description.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)),
            /// Set remote address
            "remoteAddress": .string(remoteAddress?.description ?? ""),
            /// Apodini's event loop
            "apodiniEventLoop": .string(eventLoop.description)
        ]
        .merging(self.exporterLoggingMetadata) { (_, new) in new }
        .merging(self.exporterRequestLoggingMetadata) { (_, new) in new }
        .merging(self.endpointLoggingMetadata) { (_, new) in new }
        .merging(self.informationLoggingMetadata) { (_, new) in new }
        .merging(self.parameterLoggingMetadata) { (_, new) in new }
    }
    
    private var exporterLoggingMetadata: Logger.Metadata {
        [
            /// Exporter type, full name would be 'ApodiniREST.RESTInterfaceExporter', we are only interested in the name after the point
            "exporter": .string(String(describing: self.exporter).components(separatedBy: ".")[1]),
            /// Static parameter namespace
            "exporterParameterNamespace": .array(I.parameterNamespace.map({.string($0.description)}))
        ]
    }
    
    private var exporterRequestLoggingMetadata: Logger.Metadata {
        exporterRequest.loggingMetadata
    }
    
    private var informationLoggingMetadata: Logger.Metadata {
        [
            "information":  .dictionary(self.information.reduce(into: [:]) { res, info in
                                res[info.key] = .string(info.rawValue)
                            })
        ]
        
    }
    
    private var endpointLoggingMetadata: Logger.Metadata {
        [
            /// Name of the endpoint (so the name of the handler class)
            "endpoint": .string(self.storedEndpoint.description),
            /// Absolut path of the request
            "endpointAbsolutePath": .string(self.storedEndpoint.absolutePath.asPathString()),
            /// Parameters of the endpoint, NOT the actual values
            //"endpointParameters": .string(self.storedEndpoint.parameters.description),
            "endpointParameters": .array(self.storedEndpoint.parameters.map({ parameter in .string(parameter.description)})),
            /// Handler type
            "handler": .string(String(describing: self.storedEndpoint.handler))
        ]
    }
    
    private var parameterLoggingMetadata: Logger.Metadata {
        get {
            wrappedParameterLoggingMetadata
        }
        set {
            // Directly set values to the 'parameters' key in the dictionary
            guard let validParameterLoggingMetadata = wrappedParameterLoggingMetadata["parameters"] else {
                wrappedParameterLoggingMetadata["parameters"] = .dictionary(newValue)
                return
            }
            
            wrappedParameterLoggingMetadata["parameters"] = .dictionary(validParameterLoggingMetadata.metadataDictionary.merging(newValue) { (_, new) in new })
        }
    }
    
    /// Encode the parameters to JSON and save them in the `loggingMetadata` computed variable
    private func logParameterMetadata<Element: Codable>(validatedParameter: Element, parameterID: UUID) {
        do {
            guard let parameterName = endpoint.parameters.filter({ $0.id == parameterID }).first?.name else {
                // This shouldn't be able to happen at all, therefore fail
                fatalError("Logging of parameters failed - Tried to log unknown parameter")
            }
            
            guard let encodedParameterString = String(data: try ValidatingRequest<I, H>.jsonEncoder.encode(validatedParameter), encoding: .utf8) else {
                // Since the name of the parameter is now known, write an error message to the value of the parameter in the logging metadata
                parameterLoggingMetadata = [parameterName:.string("Error encoding the parameter")]
                return
            }
            
            // Check if parameter is too large, limit is 8kb
            // TODO: This operates on the encoded string for now, but this will change nontheless soon
            guard encodedParameterString.count < 8192 else {
                parameterLoggingMetadata = [parameterName:.string("Parameter data too large")]
                return
            }

            // Write the parameter to the logging metadata
            parameterLoggingMetadata = [parameterName:.string(encodedParameterString)]
        } catch {
            // The only way an error is thrown in the "do" block above, is that the encoding of parameters failed
            fatalError("Logging of parameters failed - Encoding failed")
        }
    }
}

extension ValidatingRequest {
    /// Default `JSONEncoder`that is used for parameter encoding
    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]    // maybe .withoutEscapingSlashes? (maybe interferes with kibana?)
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+inf", negativeInfinity: "-inf", nan: "NaN")
        
        return encoder
    }
}

extension Logger.MetadataValue {
    var metadataDictionary: Logger.Metadata {
        switch self {
        case .dictionary(let dictionary):
            return dictionary
        default: return [:]
        }
    }
}

enum JSONIntermediateRepresentation: Decodable {
    case null
    case bool(Bool)
    case int(Int)
    case float(Float)
    case double(Double)
    case string(String)
    case array([JSONIntermediateRepresentation])
    case dictionary([String: JSONIntermediateRepresentation])
    
    init(from decoder: Decoder) throws {
        // Without Key: { "test": 1, "bla": "zwei" }
        let container = try decoder.singleValueContainer()
        // Array:   [1, 2, 3]
        var test = try decoder.unkeyedContainer()
        let testme = try! container.decode([JSONIntermediateRepresentation].self)
        let testmeB = try! container.decode([String: JSONIntermediateRepresentation].self)
        // With Keys: { "test": 1, "bla": "zwei" }    Difference to without keys?
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let float = try? container.decode(Float.self) {
            self = .float(float)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
//        } else if let array = try? container.decode(Array.self) {
//            fatalError("TODO: @Philipp")
//        } else if let dictionary = try? container.decode(String.self) {
//            fatalError("TODO: @Philipp")
        } else {
            fatalError("shit")
        }
    }
    
    // Probably need to let all relevant containers conform to a top protocol DecoderContainer or smt. like that
    //private func transform(_: )
    
    var metadata: Logger.Metadata {
        fatalError("TODO: @Philipp")
        // Parse the above JSON (self) to metadata
    }
}
