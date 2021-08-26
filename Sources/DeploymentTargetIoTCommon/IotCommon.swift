//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniDeployBuildSupport
import ApodiniUtils
import Apodini

/// Identifier of the iot deployment provider.
public let iotDeploymentProviderId = DeploymentProviderID("de.desiderato.ApodiniDeploymentProvider.IoT")

/// Simple lauch info for IoT runtime
public struct IoTLaunchInfo: Codable {
    public let port: Int
    public let host: URL
    
    public init(host: URL, port: Int) {
        self.host = host
        self.port = port
    }
}

public struct DeploymentDevice: PropertyOption, RawRepresentable {
    /// memory size, in MB
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static func & (lhs: DeploymentDevice, rhs: DeploymentDevice) -> DeploymentDevice {
        DeploymentDevice(rawValue: lhs.rawValue
                            .appending(".")
                            .appending(rhs.rawValue)
        )
    }
}

public extension PropertyOptionKey where PropertyNameSpace == DeploymentOptionNamespace, Option == DeploymentDevice {
    /// The ``PropertyOptionKey`` for ``MemorySize``.
    static let deploymentDevice = DeploymentOptionKey<DeploymentDevice>()
}

public extension ComponentMetadataNamespace {
    /// Name definition for the ``DeploymentMemoryMetadata``
    typealias DeploymentDevice = DeploymentDeviceMetadata
}

/// The ``DeploymentMemoryMetadata`` can be used to explicitly declare the ``MemorySize`` deployment option.
///
/// The Metadata is available under the ``ComponentMetadataNamespace/Memory`` name and can be used like the following:
/// ```swift
/// struct ExampleComponent: Component {
///     // ...
///     var metadata: Metadata {
///         Memory(.mb(128))
///     }
/// }
/// ```
public struct DeploymentDeviceMetadata: ComponentMetadataDefinition {
    public typealias Key = DeploymentOptionsContextKey

    public let value: PropertyOptionSet<DeploymentOptionNamespace>

    public init(_ value: DeploymentDevice) {
        self.value = .init(value, for: .deploymentDevice)
    }
}