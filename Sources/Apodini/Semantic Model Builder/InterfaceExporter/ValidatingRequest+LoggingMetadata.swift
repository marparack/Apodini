//
//  ValidatingRequest+LoggingMetadata.swift
//
//  Created by Philipp Zagar on 15.07.21.
//

import Foundation
import Logging

extension ValidatingRequest {
    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+inf", negativeInfinity: "-inf", nan: "NaN")
        return encoder
    }
    
    /// Encode the parameters to JSON and save them in the `loggingMetadata` computed variable
    internal func logParameterMetadata<Element: Codable>(validatedParameter: Element, parameterID: UUID) {
        do {
            guard let parameterName = endpoint.parameters.filter({ $0.id == parameterID }).first?.name else {
                /// This shouldn't be able to happen at all, therefore fail
                fatalError("Logging of parameters failed - Tried to log unknown parameter")
            }
            
            /// Encode parameter to a `Logger.Metadata` representation
            //let encodedParameter = try validatedParameter.encodeToJSON(outputFormatting: [.withoutEscapingSlashes])
            let encodedParameter = try Self.jsonEncoder.encode(validatedParameter)
            let jsonIntermediateRepresentation = try JSONDecoder().decode(JSONIntermediateRepresentation.self, from: encodedParameter)
            let parameterMetadata = jsonIntermediateRepresentation.metadata
            
            /// Check if parameter is too large, limit is fixed 8kb
            guard encodedParameter.count < 8192 else {
                // TODO: Not very pretty, but tricky to get a clean solution
                parameterLoggingMetadata["parameters"] = .dictionary(parameterLoggingMetadata["parameters"]!.metadataDictionary.merging([parameterName: .string("Parameter data too large")]) { (_, new) in new })
                return
            }
            
            /// Set the encoded parameter to the metadata dictionary
            // TODO: Not very pretty, but tricky to get a clean solution
            parameterLoggingMetadata["parameters"] = .dictionary(parameterLoggingMetadata["parameters"]!.metadataDictionary.merging([parameterName: parameterMetadata]) { (_, new) in new })
        } catch {
            fatalError("Logging of parameters failed - Encoding failed")
        }
    }
    
    internal var defaultLoggingMetadata: Logger.Metadata {
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
            "endpointParameters": .array(self.storedEndpoint.parameters.map({ parameter in .string(parameter.description)})),
            /// Handler type
            "handler": .string(String(describing: type(of: self.storedEndpoint.handler)))
        ]
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

/// An intermediate representation to encode every `Codable` object as a `Logger.Metadata` object
private enum JSONIntermediateRepresentation: Decodable, Encodable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONIntermediateRepresentation])
    case dictionary([String: JSONIntermediateRepresentation])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
         
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONIntermediateRepresentation].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: JSONIntermediateRepresentation].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Encountered unexpected JSON values"))
        }
    }
    
    /// Computed property that returns the actual `Logger.MetadataValue`
    var metadata: Logger.MetadataValue {
        switch self {
        case .null:
            return .string("null")
        case let .bool(bool):
            return .string("\(bool)")
        case let .int(int):
            return .string("\(int)")
        case let .double(double):
            return .string("\(double)")
        case let .string(string):
            return .string(string)
        case let .array(array):
            return .array(array.map({ $0.metadata }))
        case let .dictionary(dictionary):
            return .dictionary(dictionary.mapValues({ $0.metadata }))
        }
    }
}
