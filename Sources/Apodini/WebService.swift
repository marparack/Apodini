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
    /// - Parameters:
    ///    - waitForCompletion: Indicates whether the `Application` is launched or just booted. Defaults to true, meaning the `Application` is run
    ///    - webService: The instanciated `WebService` by the Swift ArgumentParser containing CLI arguments.  If `WebService` isn't already instanciated by the Swift ArgumentParser, automatically create a default instance
    /// - Returns: The application on which the `WebService` is operating on
    @discardableResult
    static func start(waitForCompletion: Bool = true, webService: Self = Self()) throws -> Application {
        let app = Application()
        // Temporarily commented out - need to solve the double logging problem (if it itsn't bootstrapped here, it will be bootstrapped in the configuration, apperently no data is lost at all?)
        //LoggingSystem.bootstrap(StreamLogHandler.standardError)
        
        var webServiceCopy = webService
        Apodini.inject(app: app, to: &webServiceCopy)
        Apodini.activate(&webServiceCopy)

        start(app: app, webService: webServiceCopy)
        
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
    

     /// This function is provided to start up an Apodini `WebService`. The `app` parameter can be injected for testing purposes only. Use `WebService.start()` to startup an Apodini `WebService`.
     /// - Parameters:
     ///    - app: The app instance that should be injected in the Apodini `WebService`
     ///    - webService: The instanciated `WebService` by the Swift ArgumentParser containing CLI arguments.  If `WebService` isn't already instanciated by the Swift ArgumentParser, automatically create a default instance
    static func start(app: Application, webService: Self = Self()) {
        /// Configure application and instanciate exporters
        webService.configuration.configure(app)
        
        // If no specific address hostname is provided we bind to the default address to automatically and correctly bind in Docker containers.
        if app.http.address == nil {
            app.http.address = .hostname(HTTPConfiguration.Defaults.hostname, port: HTTPConfiguration.Defaults.port)
        }
        
        webService.register(
            SemanticModelBuilder(app)
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

extension WebService {
    public static func main(_ arguments: [String]? = nil) {
        let mirror = Mirror(reflecting: Self())
        var propertyStore: [String: ArgumentParserStoreable] = [:]
        
        for child in mirror.children {
            if let property = child.value as? ArgumentParserStoreable {
                guard let label = child.label else {
                    fatalError("Label of the to be stored property couldn't be read!")
                }
                
                /// Store the values of the wrapped properties in a dictionary
                property.store(in: &propertyStore, keyedBy: label)
            }
        }
        
        do {
            var command = try parseAsRoot(arguments)
            
            propertyStore.forEach { propertyKey, propertyValue in
                /// Restore the values of the wrapped properties from a dictionary
                propertyValue.restore(from: propertyStore, keyedBy: propertyKey, to: &command)
            }
            
            try command.run()
        } catch {
            exit(withError: error)
        }
    }
}

/// Protocol to store and restore the values of property wrappers like `@Environment` or `@PathParameter` in the `WebService`
public protocol ArgumentParserStoreable {
    /// Stores the values of the property wrappers in a passed dictionary keyed by the name of the wrapped value
    /// - Parameters:
    ///    - store: Used to store the values of the wrapped values of the property wrappers
    ///    - key: The name of the wrapped value of the property wrapper, used as a key to store the values in a dictionary
    func store(in store: inout [String: ArgumentParserStoreable], keyedBy key: String)
    
    /// Restores the values of the property wrappers from a passed dictionary keyed by the name of the wrapped value
    /// - Parameters:
    ///    - store: Used to restore the values of the wrapped values of the property wrappers
    ///    - key: The name of the wrapped value of the property wrapper, used as a key to store the values in a dictionary
    ///    - webService: The `WebService` instance (created by the developer) to restore the values of the wrapped properties to
    func restore(from store: [String: ArgumentParserStoreable], keyedBy key: String, to webService: inout ParsableCommand)
}
