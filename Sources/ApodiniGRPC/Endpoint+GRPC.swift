//
//  Endpoint+GRPC.swift
//  
//
//  Created by Moritz Schüll on 04.01.21.
//

import Foundation
import Apodini
import ApodiniExtension

/// Provides utility functionality that is common to
/// both, the `ProtobufferInterfaceExporter` and
/// the `GRPCInterfaceExporter`.

/// Returns the name of the service that is exported by
/// the Protobuffer and GRPC exporters
/// for this `Endpoint`.
public func gRPCServiceName<H: Handler>(from endpoint: Endpoint<H>) -> String {
    if let serviceName = endpoint[Context.self].get(valueFor: GRPCServiceNameContextKey.self) {
        return serviceName
    }

    // if no explicit servicename is provided via the modifier,
    // simply use the PathComponents to come up with one
    return endpoint.absolutePath.asPathString(delimiter: "", parameterEncoding: .name)
        .capitalized
        .appending("Service")
}

/// Returns the name of the method that is exported
/// by the Protobuffer and GRPC exporters
/// for the `handle` method of this `Endpoint`.
public func gRPCMethodName<H: Handler>(from endpoint: Endpoint<H>) -> String {
    if let methodName = endpoint[Context.self].get(valueFor: GRPCMethodNameContextKey.self) {
        return methodName
    }
    // if no explicit methodname is provided via the modifier,
    // we have to rely on the component name
    return "\(H.self)".lowercased()
}
