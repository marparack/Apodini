//
//  File.swift
//  
//
//  Created by Felix Desiderato on 12/07/2021.
//

import Foundation

public struct DeploymentGroup: Codable, Hashable, Equatable {
    public typealias ID = String
    
    public let id: ID
    public let handlerTypes: Set<HandlerTypeIdentifier>
    public let handlerIds: Set<AnyHandlerIdentifier>
    
    public init(id: ID? = nil, handlerTypes: Set<HandlerTypeIdentifier>, handlerIds: Set<AnyHandlerIdentifier>) {
        self.id = id ?? Self.generateGroupId()
        self.handlerTypes = handlerTypes
        self.handlerIds = handlerIds
    }
    
    /// Utility function for generating default group ids
    public static func generateGroupId() -> ID {
        UUID().uuidString
    }
}
