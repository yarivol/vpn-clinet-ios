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
    private var continuation: AsyncStream<T>.Continuation?

    lazy var stream: AsyncStream<T> = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        self.continuation = continuation
    }

    func emit(_ value: T) {
        continuation?.yield(value)
    }
}
