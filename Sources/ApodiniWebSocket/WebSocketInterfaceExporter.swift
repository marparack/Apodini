//                   
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//              

import Apodini
import ApodiniUtils
import ApodiniExtension
import ApodiniLoggingSupport
import NIOWebSocket
import WebSocketKit
import Foundation
import ApodiniNetworking

// MARK: Exporter

public final class WebSocket: Configuration {
    let configuration: WebSocket.ExporterConfiguration
    
    public init(path: String = "apodini/websocket") {
        self.configuration = WebSocket.ExporterConfiguration(path: path)
    }
    
    public func configure(_ app: Apodini.Application) {
        /// Instantiate exporter
        let webSocketExporter = WebSocketInterfaceExporter(app, self.configuration)
        
        /// Insert exporter into `InterfaceExporterStorage`
        app.registerExporter(exporter: webSocketExporter)
    }
}

/// The WebSocket exporter uses a custom JSON based protocol on top of WebSocket's text messages.
/// This protocol can handle multiple concurrent connections on the same or different endpoints over one WebSocket channel.
/// The Apodini service listens on /apodini/websocket for clients that want to communicate via the WebSocket Interface Exporter.
final class WebSocketInterfaceExporter: LegacyInterfaceExporter {
    private let app: Apodini.Application
    private let exporterConfiguration: WebSocket.ExporterConfiguration
    private let router: VaporWSRouter

    /// Initialize a `WebSocketInterfaceExporter` from an `Application`
    init(_ app: Apodini.Application, _ exporterConfiguration: WebSocket.ExporterConfiguration = .init()) {
        self.app = app
        self.exporterConfiguration = exporterConfiguration
        self.router = VaporWSRouter(app, logger: app.logger, at: self.exporterConfiguration.path)
    }

    
    func export<H: Handler>(_ endpoint: Endpoint<H>) {
        let inputParameters: [(name: String, value: InputParameter)] = endpoint.exportParameters(on: self).map { parameter in
            (name: parameter.0, value: parameter.1.parameter)
        }
        let emptyInput = SomeInput(parameters: inputParameters.reduce(into: [String: InputParameter](), { result, parameter in
            result[parameter.name] = parameter.value
        }))
        let decodingStrategy = InterfaceExporterLegacyStrategy(self).applied(to: endpoint)
        let defaultValueStore = endpoint[DefaultValueStore.self]
        let transformer = ErrorForwardingResultTransformer(
            wrapped: Transformer<H>(),
            forwarder: endpoint[ErrorForwarder.self]
        )
        let factory = endpoint[DelegateFactory<H, WebSocketInterfaceExporter>.self]
        self.router.register({(clientInput: AnyAsyncSequence<SomeInput>, eventLoop: EventLoop, request: HTTPRequest) -> (
                    defaultInput: SomeInput,
                    output: AnyAsyncSequence<Message<H.Response.Content>>
                ) in
            // We need a new `Delegate` for each connection
            let delegate = factory.instance()
            let output = clientInput
            .reduce()
            .map { (someInput: SomeInput) -> (DefaultRequestBasis, SomeInput) in
                (DefaultRequestBasis(
                    base: someInput,
                    remoteAddress: request.remoteAddress,
                    information: request.information.merge(
                        with: [
                            LoggingMetadataInformation(key: .init("parametersValid"), rawValue: .string(someInput.parametersValid))
                        ]
                    )), someInput)
            }
            .decode(using: decodingStrategy, with: eventLoop)
            .insertDefaults(with: defaultValueStore)
            .validateParameterMutability()
            .cache()
            .forwardDecodingErrors(with: endpoint[ErrorForwarder.self])
            .subscribe(to: delegate)
            .evaluate(on: delegate)
            .transform(using: transformer)
            .typeErased

            return (defaultInput: emptyInput, output: output)
        }, on: endpoint.absolutePath.build(with: WebSocketPathBuilder.self))
    }

    func retrieveParameter<Type>(
        _ parameter: EndpointParameter<Type>,
        for request: SomeInput
    ) throws -> Type?? where Type: Decodable, Type: Encodable {
        if let inputParameter = request.parameters[parameter.name] as? BasicInputParameter<Type> {
            return inputParameter.value
        } else {
            return nil
        }
    }

    func exportParameter<Type: Codable>(_ parameter: EndpointParameter<Type>) -> (String, WebSocketParameter) {
        (parameter.name, WebSocketParameter(BasicInputParameter<Type>()))
    }
    
    struct Transformer<H: Handler>: ResultTransformer {
        func handle(error: ApodiniError) -> ErrorHandlingStrategy<Message<H.Response.Content>, Error> {
            switch error.option(for: .webSocketConnectionConsequence) {
            case .none:
                return .graceful(.error(error))
            case .closeContext:
                return .complete(.error(error))
            case .closeChannel:
                return .abort(error)
            }
        }
        
        func transform(input: H.Response.Content) -> Message<H.Response.Content> {
            Message.message(input)
        }
    }
}


// MARK: Input Definition

/// A struct that wrapps the `WebSocketInterfaceExporter`'s internal representation of
/// an `@Parameter`.
public struct WebSocketParameter {
    internal var parameter: InputParameter
    
    internal init(_ parameter: InputParameter) {
        self.parameter = parameter
    }
}


// MARK: Input Accumulation

extension SomeInput: Reducible {
    func reduce(with new: SomeInput) -> SomeInput {
        var newParameters: [String: InputParameter] = [:]
        for (name, value) in new.parameters {
            if let reducible = self.parameters[name] as? ReducibleParameter {
                newParameters[name] = reducible.reduce(to: value)
            } else {
                newParameters[name] = value
            }
        }
        return SomeInput(parameters: newParameters)
    }
}

private protocol ReducibleParameter {
    func reduce(to new: InputParameter) -> InputParameter
}

extension BasicInputParameter: ReducibleParameter {
    func reduce(to new: InputParameter) -> InputParameter {
        if let newParameter = new as? Self {
            switch newParameter.value {
            case .some:
                return new
            case .none:
                return self
            }
        } else {
            return new
        }
    }
}

// MARK: WSError Conformance

private extension ApodiniError {
    var wsError: WSError {
        switch self.option(for: .webSocketConnectionConsequence) {
        case .closeContext:
            return FatalWSError(reason: self.webSocketMessage, code: self.option(for: .webSocketErrorCode))
        default:
            return ModerateWSError(reason: self.webSocketMessage)
        }
    }
}

private struct ModerateWSError: WSError {
    var reason: String
}

private struct FatalWSError: WSClosingError {
    var reason: String
    var code: WebSocketErrorCode
}


#if DEBUG
extension ApodiniError {
    var webSocketMessage: String {
        self.message(with: messagePrefix(for: self))
    }
}

private func messagePrefix(for error: ApodiniError) -> String? {
    switch error.option(for: .errorType) {
    case .badInput:
        return "You messed up"
    case .notFound:
        return "Wow...such empty"
    case .unauthenticated:
        return "Who even are you"
    case .forbidden:
        return "You shall not pass!"
    case .serverError:
        return "I messed up"
    case .notAvailable:
        return "Not now...I'm busy"
    case .other:
        return "Something's wrong, I can feel it"
    }
}
#else
extension ApodiniError {
    var webSocketMessage: String {
        self.standardMessage
    }
}
#endif
