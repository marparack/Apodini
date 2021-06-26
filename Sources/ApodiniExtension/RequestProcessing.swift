//
//  RequestProcessing.swift
//  
//
//  Created by Max Obermeier on 23.06.21.
//

import Foundation
import OpenCombine
import Apodini
import ApodiniUtils


// MARK: Caching

public extension Publisher where Output: Request {
    func cache() -> some Publisher {
        self.map { request in
            request.cache()
        }
    }
}

public extension Request {
    func cache() -> Request {
        CachingRequest(self)
    }
}

 class CachingRequest<R: Request>: WithRequest {
    typealias InitialInput = R
    
    var request: Request {
        _request as Request
    }
    
    private var _request: R
    
    private var cache = [UUID: Any]()
    
    init(_ request: R) {
        self._request = request
    }
    
    lazy var description: String = _request.description

    lazy var debugDescription: String = _request.debugDescription

    lazy var eventLoop: EventLoop = _request.eventLoop

    lazy var remoteAddress: SocketAddress? = _request.remoteAddress
    
    lazy var information: Set<AnyInformation> = _request.information
    
    func retrieveParameter<Element>(_ parameter: Parameter<Element>) throws -> Element where Element : Decodable, Element : Encodable {
        if let cached = cache[parameter.id] as? Element {
            return cached
        }
        
        let value = try _request.retrieveParameter(parameter)
        cache[parameter.id] = value
        return value
    }
}


// MARK: Necessity Validation

public struct NecessityValidation {
    
    private let handler: (UUID) throws -> Any
    
    
    public init(for endpoint: AnyEndpoint) {
        let defaultValues = endpoint[EndpointParameters.self].reduce(into: [UUID: () -> Any](), { storage, parameter in
            if let defaultValue = parameter.typeErasuredDefaultValue, parameter.necessity == .required {
                storage[parameter.id] = defaultValue
            }
        })
        
        let descriptions = endpoint[EndpointParameters.self].reduce(into: [UUID: String](), { storage, parameter in
            storage[parameter.id] = parameter.description
        })
        
        handler = { uuid in
            if let defaultValue = defaultValues[uuid] {
                return defaultValue()
            }
            throw ApodiniError(type: .badInput, reason: "Didn't retrieve any parameters for a required parameter '\(descriptions[uuid] ?? "??")'.")
        }
    }
    
    public func validateNecessity(_ request: Request) -> Request {
        ValidatingRequest(request: request, handler: handler)
    }
    
    struct ValidatingRequest: WithRequest {
        private(set) var request: Request
        
        let handler: (UUID) throws -> Any

        func retrieveParameter<Element>(_ parameter: Parameter<Element>) throws -> Element where Element : Decodable, Element : Encodable {
            do {
                return try request.retrieveParameter(parameter)
            } catch DecodingError.keyNotFound(_, _), DecodingError.valueNotFound(_, _) {
                guard let typedValue = try handler(parameter.id) as? Element else {
                    fatalError("Internal logic of NecessityValidation broken: type mismatch")
                }
                return typedValue
            }
        }
    }
}

public extension Publisher where Output: Request {
    func validateNecessity(with validation: NecessityValidation) -> some Publisher {
        self.map { request in
            validation.validateNecessity(request)
        }
    }
}



// MARK: Mutability Validation

public extension Publisher where Output: Request {
    func validateParameterMutability() -> some Publisher {
        self.reduce(with: Optional<MutabilityValidatingRequest<Output>>.none)
    }
}

/// - Note: Must be used last in a sequence of failable `Request`s, otherwise the internal
///         state might get corrupted.
public class MutabilityValidatingRequest<R: Request>: WithRequest, Initializable {
    public typealias InitialInput = R
    
    public var request: Request {
        _request as Request
    }
    
    private var _request: R
    
    private var previousValues = [UUID: (backup: Any?, last: Any?)]()
    
    private var failed = false
    
    public required init(_ initial: R) {
        self._request = initial
    }
    
    public func retrieveParameter<Element>(_ parameter: Parameter<Element>) throws -> Element where Element : Decodable, Element : Encodable {
        do {
            let retrievedValue = try _request.retrieveParameter(parameter)
            
            switch IE.option(for: .mutability, on: parameter) ?? .variable {
            case .constant:
                if case let .some((_, .some(initialValue))) = self.previousValues[parameter.id] {
                    if !AnyEquatable.compare(initialValue as Any, retrievedValue as Any).isEqual {
                        throw ApodiniError(type: .badInput, reason: "Parameter retrieval returned value for constant '\(parameter)' even though its value has already been defined.")
                    }
                } else {
                    self.previousValues[parameter.id] = (nil, retrievedValue)
                }
            case .variable:
                break
            }
            
            return retrievedValue
        } catch {
            failed = true
            throw error
        }
    }
}

extension MutabilityValidatingRequest: Reducible {
    public typealias Input = R
    
    public func reduce(with new: R) -> Self {
        for (key, (backup, last)) in previousValues {
            previousValues[key] = failed ? (backup, backup) : (last, last)
        }
        self.failed = false
        self._request = _request
        return self
    }
}