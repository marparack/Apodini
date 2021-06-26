//
//  ConfiguredLogger.swift
//  
//
//  Created by Philipp Zagar on 09.06.21.
//

import Foundation
import Logging
//import ApodiniWebSocket

@propertyWrapper
public struct ConfiguredLogger: DynamicProperty {
    @Environment(\.connection)
    var connection: Connection
    
    @Environment(\.logger)
    var logger: Logger
    
    //@Environment(\LoggingStorageValue.configuration)
    //var loggerConfiguration: LoggerConfiguration
    
    @Environment(\.storage)
    var storage: Storage
    
    @State
    var builtLogger: Logger?
    
    @State
    var lastRequest: Int = 1
    
    private let id: UUID
    private let logLevel: Logger.Level?
    
    public var wrappedValue: Logger {
        get {
            if builtLogger == nil {
                builtLogger = .init(label: "org.apodini.observe")
                
                // setup basic logger (and parse parameters!)
                
                let request = connection.request
                
                request.loggingMetadata.forEach { key, value in
                    builtLogger?[metadataKey: key] = value
                }
                
                // Set log level - configured either by user in the property wrapper, a CLI argument/configuration in Configuration of WebService (for all loggers, set a storage entry?) or default (which is .info for the StreamLogHandler - set by the Logging Backend, so the struct implementing the LogHandler)
                /// Prio 1: User specifies a `Logger.LogLevel` in the property wrapper for a specific `Handler`
                if let logLevel = self.logLevel {
                    builtLogger?.logLevel = logLevel
                    
                    /// If logging level is configured gloally
                    if let globalConfiguredLogLevel = storage.get(LoggingStorageKey.self)?.configuration.logLevel {
                        if logLevel < globalConfiguredLogLevel {
                            print("The global configured logging level is \(globalConfiguredLogLevel.rawValue) but Handler \(request.endpoint.description) has logging level \(logLevel.rawValue) which is lower than the configured global logging level")
                        }
                    /// If logging level is automatically set to a default value
                    } else {
                        var globalLogLevel: Logger.Level
                        #if DEBUG
                        globalLogLevel = .debug
                        #else
                        globalLogLevel = .info
                        #endif
                        
                        if logLevel < globalLogLevel {
                            print("The global default logging level is \(globalLogLevel.rawValue) but Handler \(request.endpoint.description) has logging level \(logLevel.rawValue) which is lower than the global default logging level")
                        }
                    }
                }
                /// Prio 2: User specifies a `Logger.LogLevel`either via a CLI argument or via a `LoggerConfiguration` in the configuration of the `WebService`
                else if let loggingConfiguraiton = storage.get(LoggingStorageKey.self)?.configuration {
                    builtLogger?.logLevel = loggingConfiguraiton.logLevel
                }
                /// Prio 3: No `Logger.LogLevel` specified by user, use defaul value according to environment (debug mode or release mode)
                else {
                    #if DEBUG
                    builtLogger?.logLevel = .debug
                    #else
                    // TODO: Maybe use the `LogLevel` of the used logging backend (a default is specified there), so level of the `LogHandler`
                    builtLogger?.logLevel = .info
                    #endif
                }
            } else {
                /*
                /// If Websocket -> Need to check if new parameters are passed -> Parse them again if the count doesn't match
                if let webSocketInput = connection.request.raw as? WebSocketInput {
                    if lastRequest != webSocketInput.requestCount {
                        lastRequest = webSocketInput.requestCount
                        
                        // parse parameters again
                    }
                }
                 */
            }
            
            
            
            //if let cookies = (connection.request.raw as?)
            
            return builtLogger!
        }
    }
    
    private init(id: UUID = UUID(),
                 logLevel: Logger.Level? = nil) {
        self.id = id
        self.logLevel = logLevel
    }
    
    /// Creates a new `@MyLogger` without any arguments
    public init() {
        // We need to pass any argument otherwise we would call the same initializer again resulting in an infinite loop
        self.init(id: UUID())
    }
    
    /// Creates a new `@Mylogger` and specify a `Logger.Level`
    public init(logLevel: Logger.Level) {
        self.init(id: UUID(), logLevel: logLevel)
    }
    
    /// Not needed for much longer
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

/// Not needed for much longer
extension String {
    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        guard let range = self.range(of: target) else { return self }
        return self.replacingCharacters(in: range, with: replacement)
    }
}
