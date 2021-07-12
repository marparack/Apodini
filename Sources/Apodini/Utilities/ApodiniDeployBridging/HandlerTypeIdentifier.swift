//
//  File.swift
//  
//
//  Created by Felix Desiderato on 12/07/2021.
//
import Foundation

public struct HandlerTypeIdentifier: Codable, Hashable, Equatable {
    private let rawValue: String
    
    public init<H: Handler>(_: H.Type) {
        self.rawValue = "\(H.self)"
    }
    
    internal init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
    
    public static func == <H: Handler> (lhs: HandlerTypeIdentifier, rhs: H.Type) -> Bool {
        lhs == HandlerTypeIdentifier(rhs)
    }
    
    public static func == <H: Handler> (lhs: H.Type, rhs: HandlerTypeIdentifier) -> Bool {
        HandlerTypeIdentifier(lhs) == rhs
    }
}
