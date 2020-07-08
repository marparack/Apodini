//
//  GuardModifier.swift
//  
//
//  Created by Paul Schmiedmayer on 6/27/20.
//

import Vapor


private struct ResetGuard: Guard {
    func check(_ request: Vapor.Request) -> EventLoopFuture<Void> {
        fatalError("The ResetGuard is used to reset the Guards for a Component and should never be called")
    }
}

typealias LazyGuard = () -> (Guard)

struct GuardContextKey: ContextKey {
    static var defaultValue: [LazyGuard] = []
    
    static func reduce(value: inout [LazyGuard], nextValue: () -> [LazyGuard]) {
        let nextGuards = nextValue()
        for `guard` in nextGuards {
            if `guard`().self is ResetGuard {
                value = []
            } else {
                value.append(`guard`)
            }
        }
    }
}


public struct GuardModifier<C: Component>: _Modifier {
    public typealias Response = C.Response
    
    let component: C
    let `guard`: LazyGuard
    
    
    init(_ component: C, guard: @escaping @autoclosure LazyGuard) {
        self.component = component
        self.guard = `guard`
    }
    
    
    func visit<V>(_ visitor: inout V) where V : Visitor {
        visitor.addContext(GuardContextKey.self, value: [`guard`], scope: .environment)
        if let visitableComponent = component as? Visitable {
            visitableComponent.visit(&visitor)
        }
    }
    
    public func handle() -> C.Response {
        fatalError("The handle method of a Modifier should never be directly called. Call `handleInContext(of request: Request)` instead.")
    }
    
    func handleInContext(of request: Vapor.Request) -> EventLoopFuture<Vapor.Response> {
        `guard`().checkInContext(of: request)
            .flatMap {
                component.handleInContext(of: request)
            }
    }
}


extension Component {
    public func `guard`(_ guard: @escaping @autoclosure () -> (Guard)) -> GuardModifier<Self> {
        GuardModifier(self, guard: `guard`())
    }
    
    public func resetGuards() -> GuardModifier<Self> {
        GuardModifier(self, guard: ResetGuard())
    }
}
