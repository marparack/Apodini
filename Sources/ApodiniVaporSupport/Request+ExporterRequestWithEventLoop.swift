//
//  Request+ExporterRequestWithEventLoop.swift
//  
//
//  Created by Paul Schmiedmayer on 6/16/21.
//

import Apodini
import Vapor
import Foundation


extension Vapor.Request: ExporterRequestWithEventLoop {
    public var information: Set<AnyInformation> {
        Set(headers.map { key, rawValue in
            AnyInformation(key: key, rawValue: rawValue)
        })
    }
    
    /// Logging Metadata
    public var loggingMetadata: Logger.Metadata {
        [
            // Not interesting (no good data available): auth, client, password, parameters (we already have that), fileIO, storage,view,cache,query
            "RESTRequestDescription":.string(self.description),    // Includes Method, URL, HTTP version, headers and body
            "HTTPBody":.string(((self.body.data?.readableBytes ?? Int.max) < 32_768)
                               ? self.body.string ?? "HTTP body parsing error"
                               : "HTTP body too large!"),
            "HTTPContentType":.string(self.content.contentType?.description ?? ""),
            "HasSession":.string(self.hasSession.description),
            "HTTPMethod":.string(self.method.string),
            "Route":.string(self.route?.description ?? ""),
            "HTTPVersion":.string(self.version.description),
            "URL":.string(self.url.description)
        ]
    }
}
