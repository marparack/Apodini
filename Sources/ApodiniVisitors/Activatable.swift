//
//  Activatable.swift
//  
//
//  Created by Max Obermeier on 26.06.21.
//

import Foundation

/// An `_Activatable` element may allocate resources when `_activate` is called. These
/// resources may share information with any copies made from this element after `_activate`
/// was called.
public protocol _Activatable {
    /// Activates the given element.
    mutating func _activate()
}
