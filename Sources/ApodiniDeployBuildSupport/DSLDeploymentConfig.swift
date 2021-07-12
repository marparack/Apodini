//
//  File.swift
//  
//
//  Created by Lukas Kollmer on 2021-01-07.
//


import Foundation
import Runtime
import Apodini

public struct DeploymentConfig: Codable, Equatable {
    public enum DefaultGrouping: Int, Codable, Equatable {
        /// Every handler which is not explicitly put in a group will get its own group
        case separateNodes
        /// All handlers which are not explicitly put into a group will be put into a single group
        case singleNode
    }
    public let defaultGrouping: DefaultGrouping
    public let deploymentGroups: Set<DeploymentGroup>
    
    public init(defaultGrouping: DefaultGrouping = .separateNodes,
                deploymentGroups: Set<DeploymentGroup> = []) {
        self.defaultGrouping = defaultGrouping
        self.deploymentGroups = deploymentGroups
    }
}
