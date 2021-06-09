//
//  WebService.swift
//
//
//  Created by Paul Schmiedmayer on 7/6/20.
//

import Foundation
import Logging
import ArgumentParser

/// Each Apodini program consists of a `WebService`component that is used to describe the Web API of the Web Service
public protocol WebService: WebServiceMetadataNamespace, Component, ConfigurationCollection, ParsableCommand {
    typealias Metadata = AnyWebServiceMetadata
    
    /// The current version of the `WebService`
    var version: Version { get }
    
    /// An empty initializer used to create an Apodini `WebService`
    init()
}

// MARK: Metadata DSL
public extension WebService {
    /// WebService has an empty `AnyWebServiceMetadata` by default.
    var metadata: AnyWebServiceMetadata {
        Empty()
    }
}

extension WebService {
    /// This function is executed to start up an Apodini `WebService`, called by Swift ArgumentParser on instanciated `WebService` containing CLI arguments
    public mutating func run() throws {
        try Self.start(webService: self)
    }
    
    /// This function is executed to start up an Apodini `WebService`
    static func start(webService: Self? = nil) throws {
        try start(waitForCompletion: true, webService: webService ?? Self())
    }

    
    /// This function is executed to start up an Apodini `WebService`
    @discardableResult
    static func start(waitForCompletion: Bool, webService: Self? = nil) throws -> Application {
        let app = Application()
        LoggingSystem.bootstrap(StreamLogHandler.standardError)

        start(app: app, webService: webService ?? Self())
        
        guard waitForCompletion else {
            try app.boot()
            return app
        }

        defer {
            app.shutdown()
        }

        try app.run()
        return app
    }
    

    /**
     This function is provided to start up an Apodini `WebService`. The `app` parameter can be injected for testing purposes only. Use `WebService.start()` to startup an Apodini `WebService`.
     - Parameters:
         - app: The app instance that should be injected in the Apodini `WebService`
         - webService: The instanciated `WebService` by the Swift ArgumentParser
     */
    static func start(app: Application, webService webServiceTemp: Self? = nil) {
        /// If `WebService` isn't already instanciated by the Swift ArgumentParser, manually create an instance here
        let webService = webServiceTemp ?? Self()
        
        /// Configure application and instanciate exporters
        webService.configuration.configure(app)
        
        // If no specific address hostname is provided we bind to the default address to automatically and correctly bind in Docker containers.
        if app.http.address == nil {
            app.http.address = .hostname(HTTPConfiguration.Defaults.hostname, port: HTTPConfiguration.Defaults.port)
        }
        
        webService.register(
            app.exporters.semanticModelBuilderBuilder(SemanticModelBuilder(app))
        )
    }
    
    
    /// The current version of the `WebService`
    public var version: Version {
        Version()
    }
}


extension WebService {
    func register(_ modelBuilder: SemanticModelBuilder) {
        let visitor = SyntaxTreeVisitor(modelBuilder: modelBuilder)
        self.visit(visitor)
        visitor.finishParsing()
    }
    
    func visit(_ visitor: SyntaxTreeVisitor) {
        metadata.accept(visitor)

        visitor.addContext(APIVersionContextKey.self, value: version, scope: .environment)
        visitor.addContext(PathComponentContextKey.self, value: [version], scope: .environment)

        if Content.self != Never.self {
            Group {
                content
            }.accept(visitor)
        }
    }
}
