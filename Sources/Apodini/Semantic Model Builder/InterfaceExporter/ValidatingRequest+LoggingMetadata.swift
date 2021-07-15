//
//  ValidatingRequest+LoggingMetadata.swift
//
//  Created by Philipp Zagar on 15.07.21.
//

import Foundation

extension ValidatingRequest {    
    /// Not really possible to move the logging metadata code to an extension, since then eg. the `logParameterMetadata()` function isn't accessible anymore in the "main" class
    /// Ask Paul for feedback
}
