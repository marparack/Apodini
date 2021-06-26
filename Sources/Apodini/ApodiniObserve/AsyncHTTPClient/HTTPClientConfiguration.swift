//
//  HTTPClientConfiguration.swift
//  
//
//  Created by Philipp Zagar on 26.06.21.
//

import AsyncHTTPClient
import Logging


/// Configures the `HTTPClient` that can be used in `Handler`s using `@Environment(\.httpClient)`
public final class HTTPClientConfiguration: Configuration {
    private let configuration: HTTPClient.Configuration
    private let backgroundActivityLogger: Logger?
    
    /// Configures the `HTTPClient` that can be used in `Handler`s using `@Environment(\.httpClient)`
    ///
    /// For more information about the AsyncHTTPClient check out the documentation fround in the AsyncHTTPClient repository at[ https://github.com/swift-server/async-http-client](https://github.com/swift-server/async-http-client).
    /// - Parameters:
    ///   - configuration: `HTTPClient` client configuration.
    ///   - backgroundActivityLogger: The `Logger` used for logging background activity
    public init(
        configuration: HTTPClient.Configuration = HTTPClient.Configuration(),
        backgroundActivityLogger: Logger? = nil
    ) {
        self.configuration = configuration
        self.backgroundActivityLogger = backgroundActivityLogger
    }
    
    /// - Warning: Do not manually call this function, called by the `Apodini` framework.
    public func configure(_ app: Application) {
        let logger = backgroundActivityLogger ?? app.logger
        
        app.httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(app.eventLoopGroup),
            configuration: configuration,
            backgroundActivityLogger: logger
        )
    }
}
