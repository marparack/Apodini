import Foundation


/// A type erasure for the `PropertyOptionKey`
public class AnyPropertyOptionKey: NSObject {
    /// Combines two `PropertyOptionKey`s.
    /// - Parameters:
    ///   - lhs: The left hand side `PropertyOptionKey` that should be combined
    ///   - rhs: The left hand side `PropertyOptionKey` that should be combined
    /// - Returns: The combined `PropertyOptionKey`
    func combine(lhs: Any, rhs: Any) -> Any {
        fatalError("AnyPropertyOptionKey.combine should be overridden!")
    }
}


/// A `PropertyOptionKey` can be assoicated with a `PropertyNameSpace` and and store an `Option` that is associated with the `PropertyOptionKey` within the `PropertyNameSpace`.
public class PropertyOptionKey<PropertyNameSpace, Option: PropertyOption>: AnyPropertyOptionKey {
    override func combine(lhs: Any, rhs: Any) -> Any {
        guard let lhs = lhs as? Option, let rhs = rhs as? Option else {
            preconditionFailure("Both sides of the `&` have to conform to \(Option.self)")
        }
        
        return lhs & rhs
    }
}