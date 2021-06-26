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
    internal let logLevel: Logger.Level
    internal let hostname: String
    internal let port: Int

    /// initalize `LoggerConfiguration`
    public init(logLevel: Logger.Level, hostname: String = "127.0.0.1", port: Int = 31311) {
        self.logLevel = logLevel
        self.hostname = hostname
        self.port = port
    }

    /// Configure application
    public func configure(_ app: Application) {
        app.storage.set(LoggingStorageKey.self,
                        to: LoggingStorageValue(logger: app.logger, configuration: self))
        
        /// Bootstrap the logging system
        LoggingSystem.bootstrap { label in
            MultiplexLogHandler([
                StreamLogHandler.standardError(label: label),
                LogstashLogHandler.logstashOutput(label: label, app: app)
            ])
        }
    }
}

/// The storage key for Logging-related information.
public struct LoggingStorageKey: StorageKey {
    public typealias Value = LoggingStorageValue
}

/// The enclosing storage entity for OpenAPI-related information.
/// Commented out conformance to EnvironmentAccessible since the config is accessed via the storage
public struct LoggingStorageValue {
    /// The application `Logger`
    public let logger: Logger
    /// The configuration used by `Logger` instances
    public let configuration: LoggerConfiguration

    internal init(logger: Logger, configuration: LoggerConfiguration) {
        self.logger = logger
        self.configuration = configuration
    }
}
