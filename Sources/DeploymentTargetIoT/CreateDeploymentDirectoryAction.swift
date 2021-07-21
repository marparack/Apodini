//
//  File.swift
//  
//
//  Created by Felix Desiderato on 19/07/2021.
//

import Foundation
import DeviceDiscovery
import NIO
import Logging
import ApodiniUtils

/// A Default implementation of a `PostDiscoveryAction`. It looks for connected LIFX smart lamps using NIOLIFX.
struct CreateDeploymentDirectoryAction: PostDiscoveryAction {
    
    @Configuration(IoTDeploymentProperties.deploymentDirectory)
    var deploymentDir: URL

    static var identifier: ActionIdentifier = ActionIdentifier(rawValue: "createDeploymentDir")
    
    public func run(_ device: Device, on eventLoopGroup: EventLoopGroup, client: SSHClient?) throws -> EventLoopFuture<Int> {
        try client?.bootstrap()
        try client?.fileManager.createDir(on: deploymentDir, permissions: 777)
        return eventLoopGroup.next().makeSucceededFuture(0)
    }
}
