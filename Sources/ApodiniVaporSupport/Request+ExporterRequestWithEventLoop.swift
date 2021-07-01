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
            // What context can be passed by the user of the logger him/herself? The other stuff (what cant be passed by the user) should THEN be included in the metadata of the logger
            // Not interesting (no good data available): auth, client, password, parameters (we already have that), fileIO, storage,view,cache,query
            "RESTRequestDescription":.string(self.description),    // Includes Method, URL, HTTP version, headers and body
            "HTTPHeaders":.string(self.headers.description),    // This probably overlaps with the new Information type
            "HTTPBody":.string(self.body.description),
            "VaporRequestEventLoop":.string(self.eventLoop.description),    // Probably not needed
            "HTTPContentType":.string(self.content.contentType?.description ?? ""),     // HTTP content type
            "HTTPCookies":.string(self.cookies.all.description),     // also available in dictionary format ([String: Value]), maybe look into that
            "HasSession":.string(self.hasSession.description),     // just a boolean
            "HTTPmethod":.string(self.method.string),
            "Route":.string(self.route?.description ?? ""),
            "RequestType":.string(String(describing: self.route?.requestType)),
            "ResponseType":.string(String(describing: self.route?.responseType)),
            "HTTPVersion":.string(self.version.description),
            //"SessionData":.string(self.session.data.snapshot.description),     // also available in dictionary format
            "URL":.string(self.url.description)    // also more detailed parts available
            // app contains lots of stuff -> look into it more closly
            //"":.string(self.application.)
        ]
    }
}
