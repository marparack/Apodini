//
//  File.swift
//  
//
//  Created by Felix Desiderato on 21/07/2021.
//

import Foundation
import DeviceDiscovery
import ApodiniUtils

struct IoTUtils {
    static let resourceDirectory = ConfigurationProperty("key_resourceDir")
    static let deploymentDirectory = ConfigurationProperty("key_deployDir")
    static let logger = ConfigurationProperty("key_logger")
    
    static var resourceURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
    }
    
    static func copyResourcesToRemote(_ device: Device, origin: String, destination: String) throws {
        let task = Task(executableUrl: IoTDeploymentProvider._findExecutable("rsync"),
                        arguments: ["-avz",
                                    "-e",
                                    "'ssh'",
                                    origin,
                                    destination],
                        workingDirectory: nil,
                        launchInCurrentProcessGroup: true)
        print(task)
        try task.launchSyncAndAssertSuccess()
    }
    
    static func rsyncHostname(_ device: Device, username: String, path: String) -> String {
        "\(username)@\(device.ipv4Address!):\(path)"
    }
    
    static func _findExecutable(_ name: String) -> URL {
        guard let url = Task.findExecutable(named: name) else {
            fatalError("Unable to find executable '\(name)'")
        }
        return url
    }
}
