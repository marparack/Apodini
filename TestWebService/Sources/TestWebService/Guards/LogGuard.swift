//
//  LogGuard.swift
//  
//
//  Created by Paul Schmiedmayer on 1/19/21.
//

import Apodini
import ApodiniExtension
import Logging

struct LogGuard: SyncGuard {
    private let message: String
    
    @Environment(\.logger) var logger: Logger
    
    
    init(_ message: String = "LogGuard 👋") {
        self.message = message
    }
    
    
    func check() {
        logger.info("\(message)")
    }
}
