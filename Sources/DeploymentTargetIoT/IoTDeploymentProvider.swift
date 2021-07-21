//
//  File.swift
//  
//
//  Created by Felix Desiderato on 10/07/2021.
//

import Foundation
import ApodiniDeploy
import ApodiniDeployBuildSupport
import ApodiniDeployRuntimeSupport
import ArgumentParser
import DeviceDiscovery
import Apodini
import ApodiniUtils
import Logging

public struct IoTDeploymentCLI<Service: Apodini.WebService>: ParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "iot",
            abstract: "IoT Apodini deployment provider",
            discussion: """
            Deploys an Apodini web service to devices in the local network, mapping the deployed system's nodes to independent processes.
            """,
            version: "0.0.1"
        )
    }
    
    @Option(help: "The type ids that should be searched for")
    var types: [String] = ["_workstation._tcp."]
    
    @Argument(help: "Directory containing the Package.swift with the to-be-deployed web service's target")
    var inputPackageDir: String = "/Users/felice/Documents/ApodiniDemoWebService"
    
    @Option(help: "Name of the web service's SPM target/product")
    var productName: String = "ApodiniDemoWebService"
    
    @Option(help: "Remote directory of deployment")
    var deploymentDir: String = "/usr/deployment"
    
    public mutating func run() throws {
        let service = Service()
        service.runSyntaxTreeVisitor()
        
        let provider = IoTDeploymentProvider(searchableTypes: types, productName: productName, packageRootDir: URL(fileURLWithPath: inputPackageDir).absoluteURL, deploymentDir: URL(string: deploymentDir)!)
        try provider.run()
    }
    
    public init() {}
}


struct IoTDeploymentProvider: DeploymentProvider {
    static var identifier: DeploymentProviderID = DeploymentProviderID("de.desiderato.ApodiniDeploymentProvider.IoT")
    
    let searchableTypes: [String]
    let productName: String
    let packageRootDir: URL
    let deploymentDir: URL
    
    var target: DeploymentProviderTarget {
        .spmTarget(packageUrl: packageRootDir, targetName: productName)
    }
    
    private let fileManager = FileManager.default
    private let logger = Logger(label: "DeploymentTargetIoT")
    
    private let defaultUsername = "pi"
    private let defaultPassword = "rasp"
    
    func run() throws {
        
        try fileManager.initialize()
        try fileManager.setWorkingDirectory(to: packageRootDir)
        
        logger.notice("Starting deployment of \(productName)..")
        
        var buildMode: String
        #if DEBUG
        buildMode = "debug"
        #else
        buildMode = "release"
        #endif
        
        let executableUrl = packageRootDir
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent(buildMode, isDirectory: true)
            .appendingPathComponent(productName, isDirectory: false)
        
        /**
         Step 1: Retrieve web service structure.
         */
        logger.info("Retrieving web service structure")
        let wsStructure = try retrieveWebServiceStructure()
        
        let nodes = try computeDefaultDeployedSystemNodes(from: wsStructure)

        logger.info("Search for devices in the network")
        for type in searchableTypes {
            let discovery = DeviceDiscovery(DeviceIdentifier(type), domain: .local)
            discovery.actions = [CreateDeploymentDirectoryAction.self, LIFXDeviceDiscoveryAction.self]
            discovery.configuration = [
                .username: "pi",
                .password: "rasp",
                .runPostActions: true,
                IoTUtils.resourceDirectory: self.resourceURL,
                IoTUtils.deploymentDirectory: self.deploymentDir,
                IoTUtils.logger: self.logger
            ]
            
            let results = try discovery.run(2).wait()
            logger.info("Found: \(results)")
            for result in results {
                //Copy resources to remote
                let device = result.device
                let sshClient = try getSSHClient(for: device, configuration: discovery.configuration)
                setRemoteWorkingDir(sshClient)
                
                logger.info("Copying sources to remote")
                try copyResourcesToRemote(result)
                
                logger.info("Building package remotely")
                buildPackage(sshClient)
                
            }
        }
    }
    
    private func getSSHClient(for device: Device, configuration: ConfigurationStorage) throws -> SSHClient? {
        guard let username = configuration.typedValue(for: .username, to: String.self),
              let password = configuration.typedValue(for: .password, to: String.self),
              let ipAddress = device.ipv4Address else {
            return nil
        }

        return try SSHClient(username: username, password: password, ipAdress: ipAddress)
    }

    private func copyResourcesToRemote(_ result: DiscoveryResult) throws {
        // we dont need any existing build files because we moving to a different aarch
        if fileManager.directoryExists(atUrl: packageRootDir.appendingPathComponent(".build")) {
            try fileManager.removeItem(at: packageRootDir.appendingPathComponent(".build"))
        }
        try IoTUtils.copyResourcesToRemote(
            result.device,
            origin: packageRootDir.path,
            destination: IoTUtils.rsyncHostname(result.device, username: defaultUsername, path: self.deploymentDir.path))
    }

    private func buildPackage(_ client:SSHClient?) {
        client?.assertSuccessfulExecution(cmd: "swift build -Xswiftc -Xfrontend -Xswiftc -sil-verify-none -c debug")
    }
    
    private func setRemoteWorkingDir(_ client: SSHClient?) {
        client?.assertSuccessfulExecution(cmd: "cd  \(deploymentDir.appendingPathComponent(productName).path)")
    }
}

public struct IoTDeploymentOptionsInnerNamespace: InnerNamespace {
    public typealias OuterNS = DeploymentOptionsNamespace
    public static let identifier: String = "org.apodini.iot"
}

public struct DeploymentDevice: OptionValue, RawRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static func lights(_ value: String) -> Self {
        .init(rawValue: value)
    }
    
    public func reduce(with other: DeploymentDevice) -> DeploymentDevice {
        print("reduce \(self) with \(other)")
        return self
    }
}

public extension OptionKey where InnerNS == IoTDeploymentOptionsInnerNamespace, Value == DeploymentDevice {
    /// The option key used to specify a deployment device option
    static let device = OptionKeyWithDefaultValue<IoTDeploymentOptionsInnerNamespace, DeploymentDevice>(
        key: "deploymentDevice",
        defaultValue: .lights("home")
    )
}

public extension AnyOption where OuterNS == DeploymentOptionsNamespace {
    /// An option for specifying the deployment device
    static func device(_ deploymentDevice: DeploymentDevice) -> AnyDeploymentOption {
        ResolvedOption(key: .device, value: deploymentDevice)
    }
}

// MARK: - WellKnownEnvironmentVariableExecutionMode extension

public extension WellKnownEnvironmentVariableExecutionMode {
    static let iotDeploymentExecution = "true"
    static let iotDeploymentDevice = "lights"
}

// MARK: - IotDeploymentRuntime

public let iotDeploymentProviderId = DeploymentProviderID("de.desiderato.ApodiniDeploymentProvider.IoT")


public struct IoTDeploymentProviderLaunchInfo: Codable {
    public let port: Int
    public let host: String
}

public class IoTRuntime: DeploymentProviderRuntime {
    public static let identifier = iotDeploymentProviderId
    
    public let deployedSystem: DeployedSystem
    public let currentNodeId: DeployedSystem.Node.ID
    private let currentNodeCustomLaunchInfo: IoTDeploymentProviderLaunchInfo
    
    public required init(deployedSystem: DeployedSystem, currentNodeId: DeployedSystem.Node.ID) throws {
        self.deployedSystem = deployedSystem
        self.currentNodeId = currentNodeId
        guard
            let node = deployedSystem.node(withId: currentNodeId),
            let launchInfo = node.readUserInfo(as: IoTDeploymentProviderLaunchInfo.self)
        else {
            throw ApodiniDeployRuntimeSupportError(
                deploymentProviderId: Self.identifier,
                message: "Unable to read userInfo"
            )
        }
        self.currentNodeCustomLaunchInfo = launchInfo
    }
    
    public func configure(_ app: Apodini.Application) throws {
        app.http.address = .hostname(currentNodeCustomLaunchInfo.host, port: currentNodeCustomLaunchInfo.port)
    }
    
    public func handleRemoteHandlerInvocation<H: IdentifiableHandler>(
        _ invocation: HandlerInvocation<H>
    ) throws -> RemoteHandlerInvocationRequestResponse<H.Response.Content> {
        guard
            let LLI = invocation.targetNode.readUserInfo(as: IoTDeploymentProviderLaunchInfo.self),
            let url = URL(string: "\(LLI.host):\(LLI.port)")
        else {
            throw ApodiniDeployRuntimeSupportError(
                deploymentProviderId: identifier,
                message: "Unable to read port and construct url"
            )
        }
        return .invokeDefault(url: url)
    }
}

// MARK: - Move to shared package
extension IoTDeploymentProvider {
    static func _findExecutable(_ name: String) -> URL {
        guard let url = Task.findExecutable(named: name) else {
            fatalError("Unable to find executable '\(name)'")
        }
        return url
    }
}

// MARK: - IoT extensions
public enum IoTDeploymentError: Swift.Error {
    case postDiscoveryActionFailed(ActionIdentifier)
    case generic(String)
}

struct IoTDeploymentProperties {
    static let resourceDirectory = ConfigurationProperty("key_resourceDir")
    static let deploymentDirectory = ConfigurationProperty("key_deployDir")
}

extension IoTDeploymentProvider {
    var resourceURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
    }
}
