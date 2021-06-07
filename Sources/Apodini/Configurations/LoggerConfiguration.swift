//
//  LoggerConfiguration.swift
//  
//
//  Created by Philipp Zagar on 06.06.21.
//

import Foundation
import Logging

/// A `Configuration` for the `Logger`.
public final class LoggerConfiguration: Configuration {
    internal let logLevel: Logging.Logger.Level
    
    /// initalize `LoggerConfiguration`
    public init(logLevel: Logging.Logger.Level) {
        self.logLevel = logLevel
    }

    /// Configure application
    public func configure(_ app: Application) {
        app.storage.set(LoggingStorageKey.self,
                        to: LoggingStorageValue(logger: app.logger, configuration: self))
    }
}

/// The storage key for Logging-related information.
public struct LoggingStorageKey: StorageKey {
    public typealias Value = LoggingStorageValue
}

/// The enclosing storage entity for OpenAPI-related information.
public struct LoggingStorageValue {
    /// The application `Logger`
    public let logger: Logging.Logger
    /// The configuration used by `Logger` instances
    public let configuration: LoggerConfiguration

    internal init(logger: Logging.Logger, configuration: LoggerConfiguration) {
        self.logger = logger
        self.configuration = configuration
    }
}
