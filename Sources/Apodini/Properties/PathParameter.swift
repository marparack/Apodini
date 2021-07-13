import Foundation
import ApodiniUtils
import ArgumentParser
@_implementationOnly import Runtime

// Be aware that "toplevel" `PathParameter`s can also be defined by just
// defining a `@Parameter(.http(.path))` in the `Handler`.

/// A `@PathComponent` can be used in `Component`s to indicate that a part of a path is a parameter and can be read out in a `Handler`
@propertyWrapper
public struct PathParameter<Element: Codable & LosslessStringConvertible>: Decodable, ArgumentParserStoreable {
    @Boxed
    var id = UUID()
    @Boxed
    var identifyingType: IdentifyingType?
    
    /// You can never access the wrapped value of a @PathParameter.
    /// Please use a `@Parameter` wrapped property within a `Handler` to access the path property.
    public var wrappedValue: Element {
        fatalError(
            """
            You can never access the wrapped value of a @PathParameter.
            Please use a `@Parameter` wrapped property within a `Handler` to access the path property.
            """
        )
    }
    
    /// Accessing the projected value allows you to pass the `@PathParameter` to a `Handler` or `Component`
    public var projectedValue: Binding<Element> {
        parameter.projectedValue
    }
    
    
    /// Creates a new `@PathParameter`
    public init() {
        precondition(!isOptional(Element.self), "A `PathParameter` cannot annotate a property with Optional type!")
    }

    /// Creates a new `@PathParameter` specifically stating the type it identifies.
    /// The identified type must conform to `Identifiable` and the property type of the `PathParameter`
    /// must match the type of the `id` property of the  identified type.
    ///
    /// - Parameter type: The type the PathParameter value identifies.
    public init<Type: Encodable & Identifiable>(identifying type: Type.Type = Type.self) where Element == Type.ID {
        self.init()
        self.identifyingType = IdentifyingType(identifying: type)
    }
    
    /// Required because `WebService` conform to `ParsableCommand` which conforms to `Decodable`
    /// Can't be automatically synthesized by Swift
    public init(from decoder: Decoder) throws {}
}

extension PathParameter {
    /// A `Parameter` that can be used to pass the `PathParameter` to a `Handler` that contains a `@Parameter` and not a `@Binding`.
    public var parameter: Parameter<Element> {
        Parameter(from: id, identifying: identifyingType)
    }
}

extension PathParameter {
    public func store(in store: inout [String: ArgumentParserStoreable], keyedBy key: String) {
        store[key] = self
    }
    
    public func restore(from store: [String: ArgumentParserStoreable], keyedBy key: String) {
        if let storedValues = store[key] as? PathParameter {
            self.id = storedValues.id
            self.identifyingType = storedValues.identifyingType
            
//            do {
//                /// Read type information of the to be set variable from the webservice
//                let webServiceTypeInfo = try typeInfo(of: type(of: webService))
//                let propertyPathParameter = try webServiceTypeInfo.property(named: key)
//
//                /// Read type information from the to be set properties of the `PathParameter`
//                let pathParameterTypeInfo = try typeInfo(of: Self.self)
//                let pathParameterId = try pathParameterTypeInfo.property(named: "id")
//                let pathParameterIdentifyingType = try pathParameterTypeInfo.property(named: "identifyingType")
//
//                /// Read `PathParameter` from the webservice instance
//                var pathParameter = try propertyPathParameter.get(from: webService)
//                /// Set the stored values to the `PathParameter` from the webservice instance
//                try pathParameterId.set(value: storedValues.id, on: &pathParameter)
//                try pathParameterIdentifyingType.set(value: storedValues.identifyingType, on: &pathParameter)
//
//                /// Set value again to the webservice
//                try propertyPathParameter.set(value: pathParameter, on: &webService)
//            } catch {
//                fatalError("Stored properties couldn't be injected into the property wrapper. \(error)")
//            }
        } else {
            fatalError("Stored properties couldn't be read. Key=\(key)")
        }
    }
}
