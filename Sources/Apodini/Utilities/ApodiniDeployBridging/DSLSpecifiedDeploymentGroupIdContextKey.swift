//
//  File.swift
//  
//
//  Created by Felix Desiderato on 12/07/2021.
//
import Foundation
import Runtime

//TODO: Remove in later commit
public let EXPORT_HANDLER_IDS: String = "EXPORT_HANDLER_IDS"

public struct DSLSpecifiedDeploymentGroupIdContextKey: OptionalContextKey {
    public typealias Value = DeploymentGroup.ID
    
    public static func reduce(value: inout Value, nextValue: Value) {
        fatalError("Component cannot have multiple explicitly specified deployment groups. Conflicting groups are '\(value)' and '\(nextValue)'")
    }
}

extension SemanticModelBuilder {
    /// Evaluates if an endpoint should be exported. It checks if the current process has the env variable `TODO` exported.
    /// If that's the case, only endpoints are exported that are in the deployment group specified by `TODO`.
    /// If no env variable `TODO` has been set, this function does nothing.
    func evaluateEndpointExport(_ endpoint: AnyEndpoint) -> Bool {
        print(endpoint[AnyHandlerIdentifier.self])
        guard let value = ProcessInfo.processInfo.environment[EXPORT_HANDLER_IDS] else {
            // no value available, ignore call
            return true
        }
        guard let handlerId = endpoint[AnyHandlerIdentifier.self] else {
            // Should not happen
            return false
        }
        return value.contains(handlerId.rawValue)
    }
}
