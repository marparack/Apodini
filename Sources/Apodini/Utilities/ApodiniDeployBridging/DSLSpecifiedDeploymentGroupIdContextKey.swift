//
//  File.swift
//  
//
//  Created by Felix Desiderato on 12/07/2021.
//
import Foundation

//TODO: Remove in later commit
public let TEST_ENV_DEPLOY: String = "TEST_ENV_DEPLOY"
public let expected_RESULT: String = "home"

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
        guard let value = ProcessInfo.processInfo.environment[TEST_ENV_DEPLOY] else {
            // no value available, ignore call
            return true
        }
        guard let groupId = endpoint[Context.self].get(valueFor: DSLSpecifiedDeploymentGroupIdContextKey.self) else {
            // TODO: If an endpoint doesnt belong to a deployment group, we export it for now?
            return true
        }
        return value == groupId
    }
}
