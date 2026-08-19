//
//  EventEmitter.swift
//  pantherapp
//
//  One-shot event stream — the Swift/AsyncStream equivalent of Kotlin's
//  MutableSharedFlow(extraBufferCapacity = 1). Used for toast-like events
//  (login success/failure, dashboard refresh feedback, VPN errors) that
//  shouldn't replay to a view that starts observing later, unlike @Observable
//  state. A view consumes it with `for await value in emitter.stream { ... }`
//  inside a `.task { }` modifier.
//

import Foundation

final class EventEmitter<T> {
    let stream: AsyncStream<T>
    private let continuation: AsyncStream<T>.Continuation

    // Built eagerly at construction, not lazily on first `.stream` read —
    // with a lazy continuation, any emit() before the first consumer ever
    // touches `.stream` would silently drop the value (no continuation
    // exists yet to buffer it into). Building it upfront means the
    // bufferingNewest(1) policy actually protects an emit that happens to
    // race ahead of its first subscriber.
    init() {
        var continuation: AsyncStream<T>.Continuation!
        stream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
    }

    func emit(_ value: T) {
        continuation.yield(value)
    }
}
