//
//  Application+Vapor.swift
//
//
//  Created by Tim Gymnich on 27.12.20.
//

import Apodini
import ApodiniExtension
import Vapor


extension Vapor.Application {
    struct LifecycleHandlery: ApodiniExtension.LifecycleHandler {
        var app: Vapor.Application

        func didBoot(_ application: ApodiniExtension.Application) throws {
            if let address = application.http.address {
                try app.server.start(address: Vapor.BindAddress(from: address))
            } else {
                try app.server.start()
            }
            try app.boot()
        }

        func shutdown(_ application: ApodiniExtension.Application) {
            app.server.shutdown()
            app.shutdown()
        }
    }

    convenience init(from app: ApodiniExtension.Application, environment env: Vapor.Environment = .production) {
        self.init(env, .shared(app.eventLoopGroup))
        app.lifecycle.use(LifecycleHandlery(app: self))

        // HTTP2
        self.http.server.configuration.supportVersions = Set(app.http.supportVersions.map { version in
            switch version {
            case .one: return Vapor.HTTPVersionMajor.one
            case .two: return Vapor.HTTPVersionMajor.two
            }
        })
        self.http.server.configuration.tlsConfiguration = app.http.tlsConfiguration
        self.routes.defaultMaxBodySize = "1mb"
        self.logger = app.logger
    }
}


public extension ApodiniExtension.Application {
    /// Configuration related to vapor.
    var vapor: VaporApp {
        .init(application: self)
    }

    /// Holds the APNS Configuration
    struct VaporApp {
        struct ConfigurationKey: ApodiniExtension.StorageKey {
            // swiftlint:disable nesting
            typealias Value = Vapor.Application
        }

        /// The shared vapor application instance.
        public var app: Vapor.Application {
            if self.application.storage[ConfigurationKey.self] == nil {
                self.initialize()
            }
            // swiftlint:disable force_unwrapping
            return self.application.storage[ConfigurationKey.self]!
        }

        func initialize() {
            self.application.storage[ConfigurationKey.self] = .init(from: application)
        }

        private let application: ApodiniExtension.Application

        init(application: ApodiniExtension.Application) {
            self.application = application
        }
    }
}

extension Vapor.BindAddress {
    init(from address: ApodiniExtension.BindAddress) {
        switch address {
        case let .hostname(host, port):
            self = .hostname(host, port: port)
        case .unixDomainSocket(let path):
            self = .unixDomainSocket(path: path)
        }
    }
}
