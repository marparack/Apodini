//
//  Logger.swift
//  
//
//  Created by Philipp Zagar on 05.06.21.
//

import Foundation
import Logging
import ApodiniUtils
// For ATR tests
@_implementationOnly import AssociatedTypeRequirementsVisitor
import NIO

/// The `@Logger` property wrapper provides a `Logger` object for a `Component`
@propertyWrapper
public struct Logger: Property {
    private let id: UUID
    private let defaultValue: (() -> Logging.Logger)?
    private let logLevel: Logging.Logger.Level?
    
    private var storage: Box<Logging.Logger?>?
    
    private var app: Application?
    
    /// The value for the `@Logging` extended with data from the incoming request
    public var wrappedValue: Logging.Logger {
        guard let logger = storage?.value else {
            fatalError("You can only access the logger while you handle a request")
        }
        
        return logger
    }
    
    private init(id: UUID = UUID(),
                 defaultValue: (() -> Logging.Logger)? = nil,
                 logLevel: Logging.Logger.Level? = nil) {
        self.id = id
        self.defaultValue = defaultValue
        self.logLevel = logLevel
    }
    
    /// Creates a new `@Logging` without any arguments
    public init() {
        // We need to pass any argument otherwise we would call the same initializer again resulting in an infinite loop
        self.init(id: UUID())
    }
    
    /// Creates a new `@Logging` and specify a `Logger.Level`
    public init(logLevel: Logging.Logger.Level) {
        self.init(id: UUID(), logLevel: logLevel)
    }
}

/*
private protocol IdentifiableHandlerATRVisitorHelper: AssociatedTypeRequirementsVisitor {
    associatedtype Visitor = IdentifiableHandlerATRVisitorHelper
    associatedtype Input = IdentifiableHandler
    associatedtype Output
    func callAsFunction<T: IdentifiableHandler>(_ value: T) -> Output
}

private struct TestHandlerType: IdentifiableHandler {
    typealias Response = Never
    let handlerId = ScopedHandlerIdentifier<Self>("main")
}

extension IdentifiableHandlerATRVisitorHelper {
    @inline(never)
    @_optimize(none)
    fileprivate func _test() {
        _ = self(TestHandlerType())
    }
}

private struct IdentifiableHandlerATRVisitor: IdentifiableHandlerATRVisitorHelper {
    func callAsFunction<T: IdentifiableHandler>(_ value: T) -> AnyHandlerIdentifier {
        value.handlerId
    }
}


extension Handler {
    /// If `self` is an `IdentifiableHandler`, returns the handler's `handlerId`. Otherwise nil
    internal func getExplicitlySpecifiedIdentifier() -> AnyHandlerIdentifier? {
        // Intentionally using the if-let here to make sure we get an error
        // if for some reason the ATRVisitor's return type isn't an optional anymore,
        // since that (a guaranteed non-nil return value) would defeat the whole point of this function
        if let identifier = IdentifiableHandlerATRVisitor()(self) {
            return identifier
        } else {
            return nil
        }
    }
}
*/

private protocol ValidatingRequestATRVisitorHelper: AssociatedTypeRequirementsVisitor {
    associatedtype Visitor = ValidatingRequestATRVisitorHelper
    associatedtype Input = ValidatingRequest<InterfaceExporter, Handler>
    associatedtype Output

    func callAsFunction<I: InterfaceExporter, H: Handler>(_ value: ValidatingRequest<I, H>) -> Output
}

private struct ValidatingRequestATRVisitor: ValidatingRequestATRVisitorHelper {
    func callAsFunction<I: InterfaceExporter, H: Handler>(_ value: ValidatingRequest<I, H>) -> SocketAddress {
        value.remoteAddress!
    }
}

extension ValidatingRequestATRVisitorHelper {
    @inline(never)
    @_optimize(none)
    fileprivate func _test() {
        struct TestRequestType: ValidatingRequest<InterfaceExporter, Handler> {
            let remoteAddress = SocketAddress(sockaddr_un())
        }
        
        _ = self(TestRequestType())
    }
}

extension Logger: RequestInjectable {
    func someFunction<I: InterfaceExporter, H: Handler>(_ validated: ValidatingRequest<I, H>) {
        
    }
    
    func inject(using request: Request) throws {
        guard let storage = self.storage
                // Sadly not possible since no idea what the types are, would contain lots of information
              //let validatingRequest = dynamicCast(request, to: ValidatingRequest<InterfaceExporter, Handler>.self)
        else {
            fatalError("Cannot inject request information before Logger was activated.")
        }
        
        someFunction(request)
        
        /// Set label of `Logger` to handled `Endpoint` name
        storage.value = Logging.Logger(label: "org.apodini.endpoint.\(request.endpoint.description)")
        /// Identifies the current logger instance
        storage.value?[metadataKey: "logger-uuid"] = "\(self.id)"
        /// Name of the endpoint (so the name of the handler class)
        storage.value?[metadataKey: "endpoint"] = "\(request.endpoint.description)"
        /// Absolut path of the request
        // /v1
        storage.value?[metadataKey: "endpointAbsolutePath"] = "\(request.endpoint.absolutePath.asPathString())"

        /// TODO: Also set actual VALUES of the parameters -> somehow tricky to get the values
        /// If size of the value a parameter is too big -> discard it and insert error message?
        // "@Parameter var name: String = World"
        storage.value?[metadataKey: "parameters"] = .array(
            request.endpoint.parameters.map { parameter in
                .string(parameter.description)
        })
        /// Unformatted description of the request
        /// DebugDescription is absolutly useless
        /// "Validating Request:\n
        /// GET /v1?name=max HTTP/1.1\n
        /// User-Agent: PostmanRuntime/7.28.0\n
        /// Accept: */*\n
        /// Postman-Token: ac8b6c8f-2268-4313-94b0-809b34be0d92\n
        /// Host: localhost:8080\n
        /// Accept-Encoding: gzip, deflate, br\n
        /// Connection: keep-alive\n"
        
        /// Parse request description to a dictionary - Works only for REST endpoints -> eg. description with a websocket endpoint is completly empty
        storage.value?[metadataKey: "request-desciption"] = .dictionary(parseRequestDescription(request.description))
        /// Set remote address
        // "[IPv4]127.0.0.1/127.0.0.1:50052"
        storage.value?[metadataKey: "remoteAddress"] = "\(request.remoteAddress?.description ?? "")"
        
        // Set log level - configured either by user in the property wrapper, a CLI argument/configuration in Configuration of WebService (for all loggers, set a storage entry?) or default (which is .info for the StreamLogHandler - set by the Logging Backend, so the struct implementing the LogHandler)
        /// Prio 1: User specifies a `Logger.LogLevel` in the property wrapper for a specific `Handler`
        if let logLevel = self.logLevel {
            storage.value?.logLevel = logLevel
        }
        /// Prio 2: User specifies a `Logger.LogLevel`either via a CLI argument or via a `LoggerConfiguration` in the configuration of the `WebService`
        else if let loggingConfiguraiton = self.app?.storage.get(LoggingStorageKey.self)?.configuration {
            storage.value?.logLevel = loggingConfiguraiton.logLevel
        }
        /// Prio 3: No `Logger.LogLevel` specified by user, use defaul value according to environment (debug mode or release mode)
        else {
            #if DEBUG
            storage.value?.logLevel = .debug
            #else
            // TODO: Maybe use the `LogLevel` of the used logging backend (a default is specified there), so level of the `LogHandler`
            storage.value?.logLevel = .info
            #endif
        }
    }
    
    private func parseRequestDescription(_ requestDescription: String) -> Logging.Logger.Metadata {
        /// Build a dictionary out of request description string
        var dictionary: Logging.Logger.Metadata = [:]
        
        /// Parse request description string into a dictionary
        requestDescription
            /// Remove trailing "Validating " text
            .replacingFirstOccurrence(of: "Validating ", with: "")
            /// Remove first newline
            .replacingFirstOccurrence(of: "\n", with: "")
            .split(separator: "\n")
            .forEach { line in
                let lineSplit = line.split(separator: ":")
                dictionary[String(lineSplit[0])] = .string(
                    String(lineSplit[1].trimmingCharacters(in: .whitespaces)
                            + (lineSplit.indices.contains(2) ? ":" + lineSplit[2] : ""))
                )
            }
        
        return dictionary
    }
}

extension String {
    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        guard let range = self.range(of: target) else { return self }
        return self.replacingCharacters(in: range, with: replacement)
    }
}

extension Logger: ApplicationInjectable {
    mutating func inject(app: Application) {
        self.app = app
    }
}

extension Logger: ConnectionInjectable {
    func inject(connection: Connection) {
        guard let storage = self.storage else {
            fatalError("Cannot inject connection information before Logger was activated.")
        }
        
        storage.value?[metadataKey: "connection-state"] = "\(connection.state)"
    }
}

extension Logger: Activatable {
    mutating func activate() {
        self.storage = Box(self.defaultValue?())
    }
}

protocol CookieProvider {
    var cookies: HTTPCookie { get }
}
