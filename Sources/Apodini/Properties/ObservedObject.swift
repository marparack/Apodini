import Foundation

/// Property wrapper used inside of a `Handler` or `Job` that subscribes to an `ObservableObject`.
/// Changes of `@Published` properties of the `ObservableObject` will cause re-evaluations of the `Handler` or `Job`.
/// `ObservableObject`s can either be passed to the property wrapper as instances or in form of key paths from the environment.
///
/// This is helpful for service-side streams or bidirectional communication.
@propertyWrapper
public struct ObservedObject<Element: ObservableObject>: Property {
    private var objectIdentifer: ObjectIdentifier?
    private var element: Element?
    
    public var wrappedValue: Element {
        get {
            if let element = element {
                return element
            }
            guard let objId = objectIdentifer else {
                fatalError("ObjectIdentifier not present")
            }
            guard let element = EnvironmentValues.shared.values[objId] else {
                print(objId.hashValue)
                fatalError("")
            }
            
            guard let elem = element as? Element else {
                fatalError()
            }
            
            return elem
        }
        set {
            element = newValue
        }
    }
    
    /// Property to check if the evaluation of the `Handler` or `Job` was triggered by this `ObservableObject`.
    /// Read only property
    public internal(set) var changed: Bool = false
    
    /// Element passed as an object.
    public init(wrappedValue defaultValue: Element) {
        element = defaultValue
    }
    
    /// Element is injected with a key path.
    public init<Key: KeyChain>(_ keyPath: KeyPath<Key, Element>) {
        objectIdentifer = ObjectIdentifier(keyPath)
    }
}

/// Type-erased `ObservedObject` protocol.
protocol AnyObservedObject {
    /// Method to be informed about values that have changed
    func register(_ callback: @escaping () -> Void) -> Observation
}

extension ObservedObject: AnyObservedObject {
    func register(_ callback: @escaping () -> Void) -> Observation {
        let observation = Observation(callback)
    
        for property in Mirror(reflecting: wrappedValue).children {
            switch property.value {
            case let published as AnyPublished:
                published.register(observation)
            default:
                continue
            }
        }
        
        return observation
    }
}