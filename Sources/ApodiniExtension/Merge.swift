//
//  Merge.swift
//  
//
//  Created by Max Obermeier on 23.06.21.
//

import OpenCombine
import Foundation

extension Publisher {
#warning("""
    This method is a "cheap" replacement for 'Publishers.Merge', which - at the time of writing - is
    not implemented in OpenCombine (see https://github.com/OpenCombine/OpenCombine/pull/72).
    Thus a combination of 'sink' and 'PassthroughSubject' is used to merge the Publishers.
    However, this results in unlimited upsteam-demand and since downstream-demand might
    be limited, 'PasstroughSubject' might drop elements. To cope with this issue, an unlimited
    'buffer' is used behind the 'PassthroughSubject'!
""")
    func mergeValues<P: Publisher>(of other: P) -> some Publisher where Output == P.Output, Failure == P.Failure {
        var subject: PassthroughSubject<Output, Failure>? = PassthroughSubject<Output, Failure>()
        var cancellables = Set<AnyCancellable>()
        
        self.sink(receiveCompletion: { completion in
            subject?.send(completion: completion)
            subject = nil
            cancellables.removeAll()
        }, receiveValue: { value in
            subject?.send(value)
        }).store(in: &cancellables)
        
        other.sink(receiveCompletion: { completion in
            // we ignore the completion as we are only interested in the values of `other`
        }, receiveValue: { value in
            subject?.send(value)
        }).store(in: &cancellables)

        return subject!
            .buffer(size: Int.max, prefetch: .keepFull, whenFull: .dropNewest)
    }
}




//public extension Publisher {
//
//}
//
///// The `Publisher` behind `Publisher.syncMap`.
//public struct MergeMany<Upstream: Publisher, O>: Publisher {
//    public typealias Failure = Upstream.Failure
//
//    public typealias Output = Result<O, Error>
//
//    /// The publisher from which this publisher receives elements.
//    private let upstream: Upstream
//
//    /// The closure that transforms elements from the upstream publisher.
//    private let transform: (Upstream.Output) -> EventLoopFuture<O>
//
//    internal init(upstream: Upstream,
//                  transform: @escaping (Upstream.Output) -> EventLoopFuture<O>) {
//        self.upstream = upstream
//        self.transform = transform
//    }
//
//    public func receive<Downstream: Subscriber>(subscriber: Downstream)
//    where Result<O, Error> == Downstream.Input, Downstream.Failure == Failure {
//        upstream.subscribe(Inner(downstream: subscriber, map: transform))
//    }
//}
//
//
//private extension SyncMap {
//    final class Inner<Downstream: Subscriber>: Subscriber, CustomStringConvertible, CustomPlaygroundDisplayConvertible
//    where Downstream.Input == Result<O, Error>, Downstream.Failure == Failure {
//        typealias Input = Upstream.Output
//
//        typealias Failure = Downstream.Failure
//
//        private let downstream: Downstream
//
//        private let map: (Input) -> EventLoopFuture<O>
//
//        // We have to use a recursive lock here, because otherwise we could
//        // run into a deadlock in `receive` in case `map` completes quickly.
//        private let lock = NSRecursiveLock()
//
//        private var subscription: Inner?
//
//        private var completion: Subscribers.Completion<Failure>?
//
//        private var awaiting = false
//
//        let combineIdentifier = CombineIdentifier()
//
//        fileprivate init(downstream: Downstream, map: @escaping (Input) -> EventLoopFuture<O>) {
//            self.downstream = downstream
//            self.map = map
//        }
//
//        func receive(subscription: Subscription) {
//            // The onDemand function makes sure we never request a new
//            // value while awaiting a future. It always request a new value
//            // if we are not awaiting a future.
//            let subscription = Inner(upstream: subscription, onDemand: {
//                self.lock.lock()
//                if !self.awaiting {
//                    self.subscription?.requestOne()
//                }
//                self.lock.unlock()
//            })
//            self.lock.lock()
//            self.subscription = subscription
//            self.lock.unlock()
//            downstream.receive(subscription: subscription)
//        }
//
//        func receive(_ input: Input) -> Subscribers.Demand {
//            self.lock.lock()
//            self.awaiting = true
//            self.map(input).whenComplete { result in
//                self.lock.lock()
//                self.awaiting = false
//
//                // We pass the result `downstream`.
//                let demand = self.downstream.receive(result)
//                if let completion = self.completion {
//                    // In case we received a `completion` while waiting for the
//                    // future we are done after passing this `completion` `downstream`.
//                    self.subscription = nil
//                    self.lock.unlock()
//                    self.downstream.receive(completion: completion)
//                } else {
//                    // Otherwise we add the `demand` we obtained from passing
//                    // `output` to `downstream` to our `subscription` which will
//                    // also request one new value.
//                    self.subscription?.request(demand)
//                    self.lock.unlock()
//                }
//            }
//            self.lock.unlock()
//            return .none
//        }
//
//        func receive(completion: Subscribers.Completion<Failure>) {
//            self.lock.lock()
//            if !self.awaiting {
//                // If not awaiting a future right now, then we have to
//                // forward the completion right now.
//                self.subscription = nil
//                self.downstream.receive(completion: completion)
//            } else {
//                // If we are currently waiting for a future to complete,
//                // we cannot forward the completion. We have to wait until
//                // the future has completed. Thus we save the completion to
//                // be accessible when that happens.
//                self.completion = completion
//            }
//            self.lock.unlock()
//        }
//
//        var description: String { "SyncMap" }
//
//        var playgroundDescription: Any { description }
//    }
//}
//
//private extension SyncMap.Inner {
//    // This wrapper around the `upstream` `Subscription` stores
//    // the downstream demand. It provides the `requestOne` function
//    // for the `Subscriber` to request one new value from the `upstream`
//    // if the downstream has demand. The `onDemand` callback is called
//    // whenever downstream requested new demand. It can be used to call
//    // `requestOne` under certain conditions.
//    private final class Inner: Subscription {
//        var subscription: Subscription?
//
//        private var onDemand: (() -> Void)?
//
//        init(upstream: Subscription, onDemand: @escaping () -> Void) {
//            self.subscription = upstream
//            self.onDemand = onDemand
//        }
//
//        private let lock = NSRecursiveLock()
//        private var demand: Subscribers.Demand = .none
//
//        func request(_ demand: Subscribers.Demand) {
//            self.lock.lock()
//            self.demand += demand
//            self.lock.unlock()
//            self.onDemand?()
//        }
//
//        func cancel() {
//            self.subscription?.cancel()
//            self.subscription = nil
//            self.onDemand = nil
//        }
//
//        func requestOne() {
//            self.lock.lock()
//            if demand > 0 {
//                self.demand -= 1
//                self.subscription?.request(.max(1))
//            }
//            self.lock.unlock()
//        }
//    }
//}