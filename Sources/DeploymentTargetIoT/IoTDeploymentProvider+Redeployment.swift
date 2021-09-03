//
//  File.swift
//  File
//
//  Created by Felix Desiderato on 03/09/2021.
//

import Foundation
import Apodini
import ApodiniDeploy
import DeviceDiscovery

private enum EvaluationType {
    case newDevice(DiscoveryResult)
    case changedEndDevice(DiscoveryResult)
    case noChange
}

extension IoTDeploymentProvider {
    func listenForChanges() throws {
        IoTContext.logger.info("Scanning network for changes..")
        
        // Look for changes until stopped
        while true {
            for type in searchableTypes {
                let discovery = self.setup(for: type)
                
                // Run discovery
                let results = try discovery.run(2).wait()
                
                for result in results {
                    // Evaluate if & which changes occurred
                    let evaluation = try evaluateChanges(result, discovery: discovery)
                    
                    switch evaluation {
                    case .newDevice:
                        try deploy(result, discovery: discovery)
                    case .changedEndDevice:
                        try restartingWebService(on: result, discovery: discovery)
                    case .noChange:
                        continue
                    }
                }
                self.results = results
                discovery.stop()
            }
        }
    }
    
    private func evaluateChanges(_ result: DiscoveryResult, discovery: DeviceDiscovery) throws -> EvaluationType {
        let isNewDevice = !self.results.compactMap { $0.device.ipv4Address }.contains(result.device.ipv4Address!)
        
        if isNewDevice {
            // Trigger normal deployment
            IoTContext.logger.info("Detected change: New Device!")
            return .newDevice(result)
        }
        
        // It's not a new device, so there must be a counterpart in the existing results
        guard let oldResult = self.results.first(where: { $0.device.ipv4Address == result.device.ipv4Address }) else {
            // should not happen
            IoTContext.logger.info("No change detected")
            return .noChange
        }
        guard result.foundEndDevices != oldResult.foundEndDevices else {
            //nothing changed
            IoTContext.logger.info("No change detected")
            return .noChange
        }
        
        // check if we had end devices but now none
        if result.foundEndDevices.allSatisfy({ $0.value == 0 }) &&
            oldResult.foundEndDevices.contains(where: { $0.value > 0 }) {
            // if so, kill running instance and remove deployment
            IoTContext.logger.info("Detected change: Updated end devices! No end device could be found anymore")
            IoTContext.logger.info("Removing deployment directory and stopping process")
            try killInstanceOnRemote(result.device)
            try IoTContext.runTaskOnRemote("sudo rm -rdf \(deploymentDir.path)", device: result.device)
        }
        
        // check if the amount of found devices was 0 before -> this would need to copy and build first.
        if oldResult.foundEndDevices.allSatisfy({ $0.value == 0 }) &&
            result.foundEndDevices.contains(where: { $0.value > 0 }) {
            IoTContext.logger.info("Detected change: Updated end devices! First end device, previously none.")
            IoTContext.logger.info("Starting complete deployment process for device")
            return .newDevice(result)
        }
        IoTContext.logger.info("Detected change: Changed end devices!")
        return .changedEndDevice(result)
    }
    
    private func restartingWebService(on result: DiscoveryResult, discovery: DeviceDiscovery) throws {
        IoTContext.logger.info("Stopping running instance on remote")
        try killInstanceOnRemote(result.device)
        
        IoTContext.logger.info("Retrieve update structure")
        let (modelFileUrl, deployedSystem) = try retrieveDeployedSystem(result: result, postActions: discovery.actions)
        
        // Check if we have a suitable deployment node.
        // If theres none for this device, there's no point to continue
        guard let deploymentNode = try self.deploymentNode(for: result, deployedSystem: deployedSystem)
        else {
            IoTContext.logger.warning("Couldn't find a deployment node for \(String(describing: result.device.hostname))")
            return
        }
        
        // Run web service on deployed node
        IoTContext.logger.info("Restarting web service on remote node!")
        try run(on: deploymentNode, device: result.device, modelFileUrl: modelFileUrl)
    }
    
    private func killInstanceOnRemote(_ device: Device) throws {
        try IoTContext.runTaskOnRemote("tmux kill-session -t \(productName)", device: device, assertSuccess: false)
    }
}
