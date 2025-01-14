//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//
//
// This code is based on the Vapor project: https://github.com/vapor/vapor
//
// SPDX-FileCopyrightText: 2020 Qutheory, LLC
//
// SPDX-License-Identifier: MIT
//

import Apodini
import NIO
import NIOHTTP1
import NIOHTTP2
import NIOSSL
import NIOHPACK
import NIOWebSocket
import Foundation
import Logging


struct ApodiniNetworkingError: Swift.Error {
    let message: String
    let underlying: Error?
    
    init(message: String, underlying: Error? = nil) {
        self.message = message
        self.underlying = underlying
    }
}


private class ErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    
    let msg: String
    
    init(msg: String) {
        self.msg = msg
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("\(Self.self)[msg: \(msg)][pid: \(ProcessInfo.processInfo.processIdentifier)] received error: \(error)")
        context.close(promise: nil)
    }
}


/// A NIO-based HTTP server.
public final class HTTPServer {
    private struct ConfigStorage {
        let eventLoopGroupProvider: NIOEventLoopGroupProvider
        let eventLoopGroup: EventLoopGroup
        let tlsConfiguration: TLSConfiguration?
        let enableHTTP2: Bool
        let address: BindAddress
        let hostname: Hostname
        let logger: Logger
    }
    
    private enum Config {
        case app(Apodini.Application)
        case custom(ConfigStorage)
    }
    
    
    private let config: Config
    private let router: HTTPRouter
    
    private var customHTTP2StreamConfigurationMappings: [HTTP2InboundStreamConfigurator.Configuration.Mapping] = []
    
    private var channel: Channel?
    
    /// Whether the HTTP server should bind to the specified address when its `start()` function is called.
    /// This prroperty is set to `true` by default, and can be used to replace the server with a custom component
    /// responsible for receiving and handling incoming (and outgoing) HTTP requests.
    public var shouldBindOnStart = true {
        willSet {
            precondition(!isRunning, "shouldBindOnStart can only be mutated while the server is not running")
        }
    }
    
    /// Whether or not the server currently is running.
    public var isRunning: Bool {
        channel != nil
    }
    
    /// Whether or not the server should enable case insensitivity when matching incoming requests to registered routes.
    public var isCaseInsensitiveRoutingEnabled: Bool {
        get { router.isCaseInsensitiveRoutingEnabled }
        set { router.isCaseInsensitiveRoutingEnabled = newValue }
    }
    
    /// The server's event loop group
    public var eventLoopGroup: EventLoopGroup {
        switch config {
        case .app(let app):
            return app.eventLoopGroup
        case .custom(let storage):
            return storage.eventLoopGroup
        }
    }
    
    /// The server's TLS configuration
    public var tlsConfiguration: TLSConfiguration? {
        switch config {
        case .app(let app):
            return app.httpConfiguration.tlsConfiguration
        case .custom(let storage):
            return storage.tlsConfiguration
        }
    }
    
    /// Whether the server is using TLS
    public var isTLSEnabled: Bool {
        tlsConfiguration != nil
    }
    
    /// Whether or not the server should enable HTTP/2
    public var enableHTTP2: Bool {
        switch config {
        case .app(let app):
            return app.httpConfiguration.supportVersions.contains(.two)
        case .custom(let storage):
            return storage.enableHTTP2
        }
    }
    
    /// The server's bind address
    public var address: BindAddress {
        switch config {
        case .app(let app):
            return app.httpConfiguration.bindAddress
        case .custom(let storage):
            return storage.address
        }
    }
    
    /// The server's hostname
    public var hostname: Hostname {
        switch config {
        case .app(let app):
            return app.httpConfiguration.hostname
        case .custom(let storage):
            return storage.hostname
        }
    }
    
    
    private var logger: Logger {
        switch config {
        case .app(let app):
            return app.logger
        case .custom(let storage):
            return storage.logger
        }
    }
    
    private var addressString: String {
        address.addressString(isTLSEnabled: isTLSEnabled)
    }
    
    
    internal var registeredRoutes: [HTTPRouter.Route] {
        router.allRoutes
    }
    
    
    init(app: Apodini.Application) {
        self.config = .app(app)
        self.router = HTTPRouter(logger: app.logger)
    }
    
    
    /// Creates a new HTTP server
    /// - parameter eventLoopGroupProvider: Where the server should be getting its event loop from.
    /// - parameter tlsConfiguration: The server's TLS configuraton. Pass `nil` to disable TLS entirely.
    /// - parameter enableHTTP2: Whether or not the server should enable HTTP/2. Note that enabling TLS will also enable HTTP/2, regardless of this flag's value.
    /// - parameter address: The address to which the server should bind.
    /// - parameter hostname: The hostname to which the server corresponds to.
    /// - parameter logger: The logger object used by the server.
    public init(
        eventLoopGroupProvider: NIOEventLoopGroupProvider,
        tlsConfiguration: TLSConfiguration? = nil,
        enableHTTP2: Bool = false,
        address: BindAddress,
        hostname: Hostname,
        logger: Logger = .init(label: "\(HTTPServer.self)")
    ) {
        let eventLoopGroup: EventLoopGroup = {
            switch eventLoopGroupProvider {
            case .shared(let eventLoopGroup):
                return eventLoopGroup
            case .createNew:
                return MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            }
        }()
        self.config = .custom(.init(
            eventLoopGroupProvider: eventLoopGroupProvider,
            eventLoopGroup: eventLoopGroup,
            tlsConfiguration: tlsConfiguration,
            enableHTTP2: enableHTTP2,
            address: address,
            hostname: hostname,
            logger: logger
        ))
        self.router = HTTPRouter(logger: logger)
    }
    
    
    deinit {
        switch config {
        case .app:
            break
        case .custom(let configStorage):
            switch configStorage.eventLoopGroupProvider {
            case .shared:
                break
            case .createNew:
                try! self.eventLoopGroup.syncShutdownGracefully()
            }
        }
    }
    
    
    /// Start the server.
    /// This will attempt to open a NIO channel, bind it to the specified address, and set it up to handle incoming HTTP and HTTP2 requests, depending on the configuration options.
    public func start() throws {
        guard shouldBindOnStart else {
            return
        }
        guard !isRunning else {
            throw ApodiniNetworkingError(message: "Cannot start already-running servers")
        }
        guard !(enableHTTP2 && tlsConfiguration == nil) else {
            throw ApodiniNetworkingError(message: "Invalid configuration: Cannot enable HTTP/2 if TLS is disabled.")
        }
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { [weak self] (channel: Channel) -> EventLoopFuture<Void> in
                guard let self = self else {
                    fatalError("Asked to configure NIO channel for already-deallocated HTTPServer")
                }
                self.logger.notice("Configuring NIO channel pipeline. TLS: \(self.tlsConfiguration != nil), HTTP/2: \(self.enableHTTP2)")
                if let tlsConfig = self.tlsConfiguration {
                    precondition(tlsConfig.applicationProtocols.contains("h2"), "h2 not found in \(tlsConfig.applicationProtocols)")
                    let sslContext: NIOSSLContext
                    do {
                        sslContext = try NIOSSLContext(configuration: tlsConfig)
                    } catch {
                        self.logger.error("Unable to configure TLS: \(error)")
                        return channel.close(mode: .all)
                    }
                    let tlsHandler = NIOSSLServerHandler(context: sslContext)
                    return channel.pipeline.addHandler(tlsHandler)
                        .flatMap { () -> EventLoopFuture<Void> in
                            channel.configureHTTP2SecureUpgrade { channel in
                                channel.addApodiniNetworkingHTTP2Handlers(
                                    hostname: self.hostname,
                                    isTLSEnabled: self.isTLSEnabled,
                                    inboundStreamConfigMappings: self.customHTTP2StreamConfigurationMappings,
                                    httpResponder: self
                                )
                            } http1ChannelConfigurator: { channel in
                                channel.addApodiniNetworkingHTTP1Handlers(hostname: self.hostname, isTLSEnabled: self.isTLSEnabled, responder: self)
                            }
                        }
                        .flatMapError { error in
                            channel.eventLoop.makeFailedFuture(error)
                        }
                } else {
                    if self.enableHTTP2 {
                        fatalError("Invalid configuration: Cannot enable HTTP/2 if TLS is disabled.")
                    } else {
                        return channel.addApodiniNetworkingHTTP1Handlers(hostname: self.hostname, isTLSEnabled: self.isTLSEnabled, responder: self)
                    }
                }
            }
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        
        logger.info("Will bind to \(addressString)")
        switch address {
        case let .interface(hostname, port):
            let port = port ?? (tlsConfiguration != nil ? HTTPConfiguration.Defaults.httpsPort : HTTPConfiguration.Defaults.httpPort)
            channel = try bootstrap.bind(host: hostname, port: port).wait()
        case .unixDomainSocket(let path):
            channel = try bootstrap.bind(unixDomainSocketPath: path).wait()
        }
        logger.info("Server starting on \(addressString)")
    }
    
    
    /// Shut down the server, if it is running
    public func shutdown() throws {
        if let channel = channel {
            logger.info("Will shut down NIO channel bound to \(addressString)")
            try channel.close(mode: .all).wait()
            self.channel = nil
            logger.info("Did shut down NIO channel bound to \(addressString)")
        }
    }
    
    
    // MARK: Configuration
    
    /// Register a HTTP/2 stream configuration handler.
    /// This handler will be invoked as part of a new channel's configuration phase, allowing custom handlers be added to the channel.
    /// Whether or not a configuration handler will be used to configure a new cannel depends on the `Content-Type` header sent
    /// by the client with the channel-opening initial request,
    public func addIncomingHTTP2StreamConfigurationHandler(
        forContentTypes contentTypes: Set<HTTPMediaType>,
        configurationHandler: @escaping (Channel) -> EventLoopFuture<Void>
    ) {
        customHTTP2StreamConfigurationMappings.append(.init(
            triggeringContentTypes: contentTypes,
            action: .configureHTTP2Stream(configurationHandler)
        ))
    }
}


/// A `HTTPResponder` is a type that can respond to HTTP requests.
public protocol HTTPResponder {
    /// Handle a request received by the server.
    /// - Note: The responder is responsible for converting errors thrown when handling a request,
    ///         ideally by turning them into `HTTPResponse`s with an appropriate status code.
    func respond(to request: HTTPRequest) -> HTTPResponseConvertible
}


public struct DefaultHTTPResponder: HTTPResponder {
    private let imp: (HTTPRequest) -> HTTPResponseConvertible
    
    public init(_ imp: @escaping (HTTPRequest) -> HTTPResponseConvertible) {
        self.imp = imp
    }
    
    public func respond(to request: HTTPRequest) -> HTTPResponseConvertible {
        imp(request)
    }
}


/// A type on which HTTP routes can be registered
public protocol HTTPRoutesBuilder {
    /// Registers a new route on the HTTP server
    /// - parameter method: The route's HTTP method
    /// - parameter path: The route's path, expressed as a collection of path components
    /// - parameter handler: A closure which will be called to handle requests reaching this route.
    func registerRoute(_ method: HTTPMethod, _ path: [HTTPPathComponent], handler: @escaping (HTTPRequest) -> HTTPResponseConvertible)
    /// Registers a new route on the HTTP server
    /// - parameter method: The route's HTTP method
    /// - parameter path: The route's path, expressed as a collection of path components
    /// - parameter responder: The responder object responsible for responding to requests reaching this route
    func registerRoute(_ method: HTTPMethod, _ path: [HTTPPathComponent], responder: HTTPResponder)
}


public extension HTTPRoutesBuilder {
    /// Registers a new route on the HTTP server
    /// - parameter method: The route's HTTP method
    /// - parameter path: The route's path, expressed as a collection of path components
    /// - parameter handler: A closure which will be called to handle requests reaching this route.
    func registerRoute(_ method: HTTPMethod, _ path: [HTTPPathComponent], handler: @escaping (HTTPRequest) throws -> HTTPResponseConvertible) {
        self.registerRoute(method, path) { request -> HTTPResponseConvertible in
            do {
                return try handler(request)
            } catch {
                return request.eventLoop.makeFailedFuture(error) as EventLoopFuture<HTTPResponse>
            }
        }
    }
    
    /// Registers a new route on the HTTP server
    /// - parameter method: The route's HTTP method
    /// - parameter path: The route's path, expressed as a collection of path components
    /// - parameter responder: The responder object responsible for responding to requests reaching this route
    func registerRoute(_ method: HTTPMethod, _ path: [HTTPPathComponent], responder: HTTPResponder) {
        self.registerRoute(method, path) { request -> HTTPResponseConvertible in
            responder.respond(to: request)
        }
    }
}


extension HTTPServer: HTTPRoutesBuilder {
    public func registerRoute(_ method: HTTPMethod, _ path: [HTTPPathComponent], handler: @escaping (HTTPRequest) -> HTTPResponseConvertible) {
        router.add(HTTPRouter.Route(
            method: method,
            path: path,
            responder: DefaultHTTPResponder(handler)
        ))
    }
}


extension HTTPServer: HTTPResponder {
    public func respond(to request: HTTPRequest) -> HTTPResponseConvertible {
        let start = Date().timeIntervalSince1970
        if let route = router.getRoute(for: request) {
            return route.responder
                .respond(to: request)
                .makeHTTPResponse(for: request)
        } else {
            return HTTPResponse(version: request.version, status: .notFound, headers: [:])
        }
        let end = Date().timeIntervalSince1970
        logger.notice("Took \(end - start) seconds.")
        print("Took \(end - start) seconds.")
    }
}


extension Channel {
    func addApodiniNetworkingHTTP2Handlers(
        hostname: Hostname,
        isTLSEnabled: Bool,
        inboundStreamConfigMappings: [HTTP2InboundStreamConfigurator.Configuration.Mapping],
        httpResponder: HTTPResponder
    ) -> EventLoopFuture<Void> {
        let targetWindowSize: Int = numericCast(UInt16.max)
        return self.pipeline.addHandlers([
            NIOHTTP2Handler(mode: .server, initialSettings: [
                HTTP2Setting(parameter: .maxConcurrentStreams, value: 50),
                HTTP2Setting(parameter: .maxHeaderListSize, value: HPACKDecoder.defaultMaxHeaderListSize),
                HTTP2Setting(parameter: .maxFrameSize, value: 1 << 14),
                HTTP2Setting(parameter: .initialWindowSize, value: targetWindowSize)
            ]),
            HTTP2StreamMultiplexer(mode: .server, channel: self, targetWindowSize: targetWindowSize) { stream in
                stream.pipeline.addHandler(
                    HTTP2InboundStreamConfigurator(
                        configuration: .init(
                            mappings: inboundStreamConfigMappings,
                            defaultAction: .forwardToHTTP1Handler(httpResponder)
                        ),
                        hostname: hostname,
                        isTLSEnabled: isTLSEnabled
                    )
                )
            },
            ErrorHandler(msg: "http2.channel.error")
        ])
    }
    
    
    func initializeHTTP2InboundStreamUsingHTTP2ToHTTP1Converter(
        hostname: Hostname,
        isTLSEnabled: Bool,
        responder: HTTPResponder
    ) -> EventLoopFuture<Void> {
        pipeline.addHandlers([
            HTTP2FramePayloadToHTTP1ServerCodec(),
            HTTPServerResponseEncoder(),
            HTTPServerRequestDecoder(hostname: hostname, isTLSEnabled: isTLSEnabled),
            HTTPServerRequestHandler(responder: responder),
            ErrorHandler(msg: "http2.stream.error")
        ])
    }
    
    
    func addApodiniNetworkingHTTP1Handlers(
        hostname: Hostname,
        isTLSEnabled: Bool,
        responder: HTTPResponder
    ) -> EventLoopFuture<Void> {
        var httpHandlers: [RemovableChannelHandler] = []
        let httpResponseEncoder = HTTPResponseEncoder()
        httpHandlers += [
            httpResponseEncoder,
            ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)),
            HTTPServerResponseEncoder(),
            HTTPServerRequestDecoder(hostname: hostname, isTLSEnabled: isTLSEnabled)
        ]
        let httpRequestHandler = HTTPServerRequestHandler(responder: responder)
        let upgrader = HTTPUpgradeHandler(
            handlersToRemoveOnWebSocketUpgrade: httpHandlers.appending(httpRequestHandler)
        )
        httpHandlers.append(contentsOf: [upgrader, httpRequestHandler] as [RemovableChannelHandler])
        return pipeline.addHandlers(httpHandlers).flatMap {
            self.pipeline.addHandler(ErrorHandler(msg: "HTTP1Pipeline"))
        }
    }
}
