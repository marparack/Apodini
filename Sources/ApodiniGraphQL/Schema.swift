//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Apodini
import ApodiniUtils
import ApodiniExtension
import GraphQL
import ApodiniTypeInformation


extension TypeInformation {
    func isEqual(to type: Any.Type) -> Bool {
        try! self == .init(type: type)
    }
}


class GraphQLSchemaBuilder {
    enum SchemaError: Swift.Error {
        case unableToConstructInputType(TypeInformation, underlying: Swift.Error?)
        case unableToConstructOutputType(TypeInformation, underlying: Swift.Error)
        /// Two or more handlers have defined the same key
        case duplicateEndpointNames(String)
        case unsupportedOpCommPatternTuple(Apodini.Operation, CommunicationPattern)
        /// There must be at least one query handler (i.e. an unary handler w/ a `.read` operation type) in the web service
        case missingQueryHandler
        case unableToParseDateScalar(Any)
        /// The error thrown if the schema encounters an unsupported 64-bit integer type (GraphQL only supports 32-bit integers),
        /// - Note: It is possible to enable support for 64-bit integers (implemented as a custom scalar type),
        ///         by passing the relevant flag to the schema (and the Interface Exporter, if you're developing a web service).
        case unsupported64BitIntegerType(TypeInformation)
        case other(String)
    }
    
    
    private enum TypeUsageContext {
        case input, output
    }
    
    
    private struct TypesCacheEntry {
        let input: GraphQLInputType?
        let output: GraphQLOutputType
        
        init(inputType: GraphQLInputType? = nil, outputType: GraphQLOutputType) {
            self.input = inputType
            self.output = outputType
        }
        
        init(inputAndOutputType type: GraphQLInputType & GraphQLOutputType) {
            self.input = type
            self.output = type
        }
        
        func map(
            input inputTransform: (GraphQLInputType) -> GraphQLInputType,
            output outputTransform: (GraphQLOutputType) -> GraphQLOutputType
        ) -> Self {
            Self(
                inputType: input.map(inputTransform),
                outputType: outputTransform(output)
            )
        }
        
        func type(for usageCtx: TypeUsageContext) -> GraphQLType? {
            switch usageCtx {
            case .input:
                return self.input
            case .output:
                return self.output
            }
        }
    }
    
    
    /// The `DateFormatter` which should be used to encode and decode `Date` objects passed around in GraphQL
    static let dateFormatter: DateFormatter = { () -> DateFormatter in
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")!
        return dateFormatter
    }()
    
    
    // key: field name on the root query thing
    private var queryHandlers: [String: GraphQLField] = [:]
    private var mutationHandlers: [String: GraphQLField] = [:]
    
    private var cachedTypeMappings: [TypeInformation: TypesCacheEntry] = [:]
    
    private(set) var finalizedSchema: GraphQLSchema?
    
    private let enableCustom64BitIntScalars: Bool
    
    var isMutable: Bool { finalizedSchema == nil }
    
    
    init(enableCustom64BitIntScalars: Bool) {
        self.enableCustom64BitIntScalars = enableCustom64BitIntScalars
        Map.encoder.dateEncodingStrategy = .formatted(Self.dateFormatter)
        Map.encoder.dataEncodingStrategy = .base64
    }
    
    
    private func assertSchemaMutable(_ caller: StaticString = #function) throws {
        precondition(isMutable, "Invalid operation '\(caller)': schema is already finalized")
    }
    
    
    func add<H: Handler>(_ endpoint: Endpoint<H>) throws {
        let operation = endpoint[Operation.self]
        let commPattern = endpoint[CommunicationPattern.self]
        switch (operation, commPattern) {
        case (.read, .requestResponse):
            try addQueryOrMutationEndpoint(to: &queryHandlers, endpoint: endpoint, endpointKind: .query)
        case (.create, .requestResponse), (.update, .requestResponse), (.delete, .requestResponse):
            try addQueryOrMutationEndpoint(to: &mutationHandlers, endpoint: endpoint, endpointKind: .mutation)
        case (.read, .serviceSideStream):
            try addSubscriptionEndpoint(endpoint)
        default:
            throw SchemaError.unsupportedOpCommPatternTuple(operation, commPattern)
        }
    }
    
    
    private enum GraphQLEndpointKind {
        case query, mutation
    }
    
    private func addQueryOrMutationEndpoint<H: Handler>(
        to handlers: inout [String: GraphQLField],
        endpoint: Endpoint<H>,
        endpointKind: GraphQLEndpointKind
    ) throws {
        try assertSchemaMutable()
        let endpointName: String
        switch endpointKind {
        case .query:
            endpointName = endpoint.getEndointName(.noun, format: .camelCase)
        case .mutation:
            endpointName = endpoint.getEndointName(.verb, format: .camelCase)
        }
        guard !handlers.keys.contains(endpointName) else {
            throw SchemaError.duplicateEndpointNames(endpointName)
        }
        handlers[endpointName] = GraphQLField(
            type: try toGraphQLOutputType(.init(type: H.Response.Content.self)),
            args: try mapEndpointParametersToFieldArgs(endpoint),
            resolve: makeQueryOrMutationFieldResolver(for: endpoint),
            subscribe: nil
        )
    }
    
    
    private func makeQueryOrMutationFieldResolver<H: Handler>(for endpoint: Endpoint<H>) -> GraphQLFieldResolve {
        let defaults = endpoint[DefaultValueStore.self]
        let delegateFactory = endpoint[DelegateFactory<H, GraphQLInterfaceExporter>.self]
        return { _, args, _, eventLoopGroup, _ -> EventLoopFuture<Any?> in
            let delegate = delegateFactory.instance()
            let decodingStrategy = GraphQLEndpointDecodingStrategy().applied(to: endpoint).typeErased
            let responseFuture: EventLoopFuture<Apodini.Response<H.Response.Content>> = decodingStrategy
                .decodeRequest(from: args, with: DefaultRequestBasis(), with: eventLoopGroup.next())
                .insertDefaults(with: defaults)
                .cache()
                .forwardDecodingErrors(with: endpoint[ErrorForwarder.self])
                .evaluate(on: delegate)
            return responseFuture
                .map { $0.content }
                .inspectFailure {
                    endpoint[ErrorForwarder.self].forward($0)
                }
        }
    }
    
    
    private func addSubscriptionEndpoint<H: Handler>(_ endpoint: Endpoint<H>) throws {
        throw SchemaError.unsupportedOpCommPatternTuple(endpoint[Operation.self], endpoint[CommunicationPattern.self])
    }
    
    
    private func toGraphQLInputType(_ typeInfo: TypeInformation) throws -> GraphQLInputType {
        do {
            if let inputType = try toGraphQLType(typeInfo, for: .input).input {
                return inputType
            } else {
                throw SchemaError.unableToConstructInputType(typeInfo, underlying: nil)
            }
        } catch {
            throw SchemaError.unableToConstructInputType(typeInfo, underlying: error)
        }
    }
    
    
    private func toGraphQLOutputType(_ typeInfo: TypeInformation) throws -> GraphQLOutputType {
        do {
            return try toGraphQLType(typeInfo, for: .output).output
        } catch {
            throw SchemaError.unableToConstructOutputType(typeInfo, underlying: error)
        }
    }
    
    
    private var currentTypeStack: Stack<TypeInformation> = []
    
    
    private func toGraphQLType(_ typeInfo: TypeInformation, for usageCtx: TypeUsageContext) throws -> TypesCacheEntry {
        if let cached = cachedTypeMappings[typeInfo] {
            return cached
        }
        let result: TypesCacheEntry
        switch typeInfo {
        case .scalar, .repeated, .dictionary, .enum, .object, .reference:
            result = try _toGraphQLType(typeInfo, for: usageCtx).map(
                input: { GraphQLNonNull($0 as! GraphQLNullableType) },
                output: { GraphQLNonNull($0 as! GraphQLNullableType) }
            )
        case .optional(let wrappedValue):
            result = try _toGraphQLType(wrappedValue, for: usageCtx).map(
                input: { (($0 as? GraphQLNonNull)?.ofType as? GraphQLInputType) ?? $0 },
                output: { ($0 as? GraphQLNonNull)?.ofType as! GraphQLOutputType }
            )
        }
        precondition(cachedTypeMappings.updateValue(result, forKey: typeInfo) == nil)
        return result
    }
    
    
    private func _toGraphQLType(_ typeInfo: TypeInformation, for usageCtx: TypeUsageContext) throws -> TypesCacheEntry { // swiftlint:disable:this cyclomatic_complexity line_length
        precondition(!currentTypeStack.contains(typeInfo))
        if let cached = cachedTypeMappings[typeInfo] {
            return cached
        }
        currentTypeStack.push(typeInfo)
        defer {
            precondition(currentTypeStack.pop() == typeInfo)
        }
        switch typeInfo {
        case .scalar(let primitiveType):
            switch primitiveType {
            case .null:
                throw SchemaError.other("Unexpected null type: \(typeInfo)")
            case .bool:
                return .init(inputAndOutputType: GraphQLBoolean)
            case .float:
                return .init(inputAndOutputType: GraphQLFloat)
            case .double:
                return .init(inputAndOutputType: GraphQLFloat)
            case .int32:
                return .init(inputAndOutputType: GraphQLInt)
            case .int8, .uint8, .int16, .uint16, .uint32:
                return .init(inputAndOutputType: GraphQLInt)
            case .int, .int64:
                if enableCustom64BitIntScalars {
                    return .init(inputAndOutputType: GraphQLInt64)
                } else {
                    throw SchemaError.unsupported64BitIntegerType(typeInfo)
                }
            case .uint, .uint64:
                if enableCustom64BitIntScalars {
                    return .init(inputAndOutputType: GraphQLUInt64)
                } else {
                    throw SchemaError.unsupported64BitIntegerType(typeInfo)
                }
            case .string:
                return .init(inputAndOutputType: GraphQLString)
            case .url:
                return .init(inputAndOutputType: GraphQLURL)
            case .uuid:
                return .init(inputAndOutputType: GraphQLID)
            case .date:
                return .init(inputAndOutputType: GraphQLDate)
            case .data:
                return .init(inputAndOutputType: GraphQLData)
            }
        case .repeated(let element):
            let type = try toGraphQLType(element, for: usageCtx)
            return .init(
                inputType: GraphQLList(type.input!),
                outputType: GraphQLList(type.output)
            )
        case .dictionary:
            throw SchemaError.other("Unsupported type: GraphQL does not support non-object-type dictionaries.")
        case .optional:
            throw SchemaError.other("Unexpected Optional Type: \(typeInfo)")
        case let .enum(name, rawValueType: _, cases, context: _):
            if typeInfo.isEqual(to: Never.self) {
                // The Never type can't really be represented in GraphQL.
                // We essentially have 2 options:
                // 1. Map this into a field w/ an empty return type (i.e. a type that has no fields, and thus can't be instantiatd. though the same thing doesnt work for enums...)
                let desc = "The Never type exists to model a type which cannot be instantiated, and is used to indicate that a field does not return a result, but instead will result in a guaranteed error." // swiftlint:disable:this line_length
                return .init(
                    inputType: try GraphQLInputObjectType(
                        name: "Never",
                        description: desc,
                        fields: ["_": InputObjectField(type: GraphQLInt)]
                    ),
                    outputType: try GraphQLObjectType(
                        name: "Never",
                        description: desc,
                        fields: ["_": GraphQLField(type: GraphQLInt)]
                    )
                )
            }
            return .init(inputAndOutputType: try GraphQLEnumType(
                name: name.buildName(),
                description: nil,
                values: cases.mapIntoDict { enumCase -> (String, GraphQLEnumValue) in
                    (enumCase.name, GraphQLEnumValue(value: .string(enumCase.name)))
                }
            ))
        case let .object(name, properties, context: _):
            return .init(
                inputType: try GraphQLInputObjectType(
                    name: "\(name.buildName())Input",
                    fields: try properties.mapIntoDict { property -> (String, InputObjectField) in
                        (property.name, InputObjectField(type: try toGraphQLInputType(property.type)))
                    }
                ),
                outputType: try GraphQLObjectType(
                    name: name.buildName(),
                    description: nil,
                    fields: try properties.mapIntoDict { property -> (String, GraphQLField) in
                        (property.name, GraphQLField(type: try toGraphQLOutputType(property.type)))
                    }
                )
            )
        case .reference:
            throw SchemaError.other("Unhandled .reference type: \(typeInfo)")
        }
    }
    
    
    private func mapEndpointParametersToFieldArgs<H>(_ endpoint: Endpoint<H>) throws -> GraphQLArgumentConfigMap {
        guard !endpoint.parameters.isEmpty else {
            return [:]
        }
        var argsMap: GraphQLArgumentConfigMap = [:]
        for parameter in endpoint.parameters {
            argsMap[parameter.name] = GraphQLArgument(
                type: try toGraphQLInputType(.init(type: parameter.originalPropertyType)),
                description: nil,
                defaultValue: try { () -> Map? in
                    if let defaultValueBlock = parameter.typeErasedDefaultValue {
                        let defaultValue = defaultValueBlock()
                        if let date = defaultValue as? Date {
                            return .string(Self.dateFormatter.string(from: date))
                        } else {
                            return try map(from: defaultValue)
                        }
                    } else {
                        // The endpoint parameter does not specify a default value,
                        // meaning that the only adjustment we make is to default Optionals to `nil` if possible
                        return parameter.nilIsValidValue ? .null : nil
                    }
                }()
            )
        }
        return argsMap
    }
    
    
    @discardableResult
    func finalize() throws -> GraphQLSchema {
        if let finalizedSchema = finalizedSchema {
            return finalizedSchema
        }
        guard !queryHandlers.isEmpty else {
            throw SchemaError.missingQueryHandler
        }
        self.finalizedSchema = try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                description: "The query type contains all query-mapped handlers in a web service, i.e. all `Handler`s with a `.read` operation type and the unary communication pattern.", // swiftlint:disable:this line_length
                fields: queryHandlers
            ),
            mutation: mutationHandlers.isEmpty ? nil : GraphQLObjectType(
                name: "Mutation",
                description: nil,
                fields: mutationHandlers
            )
        )
        return finalizedSchema! // Force-unwrap is fine bc we just assigned the variable above
    }
}


// MARK: Custom Scalars

let GraphQLDate = try! GraphQLScalarType( // swiftlint:disable:this identifier_name
    name: "Date",
    description: "A custom scalar type representing Date objects, encoded as ISO8601-formatted strings (using `\(GraphQLSchemaBuilder.dateFormatter.dateFormat!)` as the format) in the \(GraphQLSchemaBuilder.dateFormatter.timeZone!.abbreviation()!) time zone.",
    serialize: { (input: Any) -> Map in
        guard let date = input as? Date else {
            return try Map(any: input)
        }
        return .string(GraphQLSchemaBuilder.dateFormatter.string(from: date))
    },
    parseValue: { (input: Map) -> Map in
        if let string = input.string {
            return .string(string)
        } else {
            return .null
        }
    },
    parseLiteral: { (value: Value) -> Map in
        if let string = (value as? StringValue)?.value {
            return .string(string)
        } else if let intNode = (value as? IntValue)?.value, let intValue = Int(intNode) {
            return .int(intValue)
        } else if let floatNode = (value as? FloatValue)?.value, let floatValue = Double(floatNode) {
            return .double(floatValue)
        } else {
            return .null
        }
    }
)

let GraphQLInt64 = try! GraphQLScalarType( // swiftlint:disable:this identifier_name
    name: "Int64",
    description: "A custom 64-bit signed integer scalar type",
    serialize: { (input: Any) -> Map in
        if let intValue = (input as? Int) ?? (input as? Int64).map(Int.init) {
            return .number(Number(intValue))
        } else {
            return .null
        }
    },
    parseValue: { (input: Map) -> Map in
        input
    },
    parseLiteral: { (value: Value) -> Map in
        if let stringValue = (value as? IntValue)?.value ?? (value as? StringValue)?.value, let intValue = Int64(stringValue) {
            return .number(Number(intValue))
        } else {
            return nil
        }
    }
)

let GraphQLUInt64 = try! GraphQLScalarType( // swiftlint:disable:this identifier_name
    name: "UInt64",
    description: "A custom 64-bit unsigned integer scalar type",
    serialize: { (input: Any) -> Map in
        if let intValue = (input as? UInt) ?? (input as? UInt64).map(UInt.init) {
            return .number(Number(intValue))
        } else {
            return .null
        }
    },
    parseValue: { (input: Map) -> Map in
        input
    },
    parseLiteral: { (value: Value) -> Map in
        if let stringValue = (value as? IntValue)?.value ?? (value as? StringValue)?.value, let intValue = UInt64(stringValue) {
            return .number(Number(intValue))
        } else {
            return nil
        }
    }
)

let GraphQLURL = try! GraphQLScalarType( // swiftlint:disable:this identifier_name
    name: "URL",
    description: "Uniform Resource Locator",
    serialize: { (input: Any) throws -> Map in
        guard let url = input as? URL else {
            throw GraphQLError(message: "Unable to serialize URL from type '\(type(of: input))'. Expected a '\(URL.self)' object.")
        }
        return .string(url.absoluteURL.absoluteString)
    },
    parseValue: { (input: Map) throws -> Map in
        input
    },
    parseLiteral: { (value: Value) throws -> Map in
        if let stringValue = (value as? StringValue)?.value {
            return .string(stringValue)
        } else {
            return .null
        }
    }
)

let GraphQLData = try! GraphQLScalarType( // swiftlint:disable:this identifier_name
    name: "Data",
    description: "Base-64 encoded raw binary data type",
    serialize: { (input: Any) throws -> Map in
        guard let data = input as? Data else {
            throw GraphQLError(message: "Unable to serialize Data from type '\(type(of: input))'. Expected a '\(Data.self)' object.")
        }
        return .string(data.base64EncodedString())
    },
    parseValue: { (input: Map) throws -> Map in
        input
    },
    parseLiteral: { (value: Value) throws -> Map in
        if let stringValue = (value as? StringValue)?.value {
            return .string(stringValue)
        } else {
            return .null
        }
    }
)
