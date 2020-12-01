#  Dynamic Property

A developer may want to create Property Wrappers that combine multiple of our Property Wrappers into one.
For that we provide the protocol Dynamic Property:

```swift
public protocol DynamicProperty {
    func update(eventLoop: EventLoop) -> EventLoopFuture<Void>
}
```

Any dynamic property behaves like a Request Injectable. However, it itself cannot receive the values from the request, but use other request injectables to poputale itself.

## Lifecycle

While Apodini is injecting all the request injectibles into a Handler, on any dynamic property, it will use reflection to inject the request injectibles inside the dynamic property.
After that it will call the update function to tell the property to populate any of it's properties.

## Example

Let's say that for example we create a Property Wrapper that reads the Authentication Header and gets us a User for the request:

```swift
protocol Authenticatable {
    static func user(with token: String) -> EventLoopFuture<Self> 
}

@propertyWrapper
struct Authenticated<User: Authenticable>: DynamicProperty {
    @Parameter("Authentication", .http(.header)
    private var token: String?
    
    @State
    private var user: User?
    
    var wrappedValue: User?
        get {
            return self.user
        }
        set {
            self.user = newValue
        }
    
    func update(eventLoop: EventLoop) -> EventLoopFuture<Void> {
        guard let token = token else {
            return eventLoop.future()
        }
        
        return User
            .user(with: token)
            .always { result in 
                guard case .success(let user) = result else { return }
                self.user = user
            }
            .map { _ in () }
    }
}
````
