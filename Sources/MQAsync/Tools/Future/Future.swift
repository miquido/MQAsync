import struct Atomics.UnsafeAtomic

public final class Promise<Value>: @unchecked Sendable
where Value: Sendable {

	@usableFromInline internal let lock: UnsafeLock
	@usableFromInline internal var continuation: UnsafeContinuation<Value, Error>?
	@usableFromInline internal var cancelation: (@Sendable () -> Void)?

	@inlinable internal init() {
		self.lock = .unsafe_init()
		self.continuation = .none
		self.cancelation = .none
	}

	deinit {
		self.lock.unsafe_deinit()
		if let continuation: UnsafeContinuation<Value, Error> = self.continuation {
			continuation.resume(throwing: CancellationError())
			self.cancelation?()
		}
		else {
			// noop - already finished
		}
	}

	public var finished: Bool {
		@Sendable _read {
			self.lock.unsafe_lock()
			yield self.continuation == nil
			self.lock.unsafe_unlock()
		}
	}

	@inlinable @Sendable public func fulfill(
		with value: consuming Value
	) {
		self.lock.unsafe_lock()
		let continuation: UnsafeContinuation<Value, Error>? = self.continuation.take()
		self.cancelation = .none
		self.lock.unsafe_unlock()
		continuation?.resume(returning: value)
	}

	@inlinable @inline(__always) @Sendable public func fulfill()
	where Value == Void {
		self.fulfill(with: Void())
	}

	@inlinable @Sendable public func fail(
		with error: consuming Error
	) {
		self.lock.unsafe_lock()
		let continuation: UnsafeContinuation<Value, Error>? = self.continuation.take()
		self.cancelation = .none
		self.lock.unsafe_unlock()
		continuation?.resume(throwing: error)
	}

	@inlinable @Sendable public func cancel() {
		self.lock.unsafe_lock()
		let continuation: UnsafeContinuation<Value, Error>? = self.continuation.take()
		let cancelation: (@Sendable () -> Void)? = self.cancelation.take()
		self.lock.unsafe_unlock()
		continuation?.resume(throwing: CancellationError())
		cancelation?()
	}

	@usableFromInline @inline(__always) @Sendable internal func prepared(
		with continuation: consuming UnsafeContinuation<Value, Error>
	) -> Bool {
		self.lock.unsafe_lock()
		assert(self.cancelation == nil)
		if Task.isCancelled {
			self.lock.unsafe_unlock()
			continuation.resume(throwing: CancellationError())
			return false
		}
		else {
			self.continuation = continuation
			self.lock.unsafe_unlock()
			return true
		}
	}

	@inlinable @Sendable public func setCancelationHandler(
		_ handler: @escaping @Sendable () -> Void
	) {
		self.lock.unsafe_lock()
		assert(self.cancelation == nil)
		if case .some = self.continuation {
			self.lock.unsafe_unlock()
			self.cancelation = handler
		}
		else {
			self.lock.unsafe_unlock()
			handler()
		}
	}
}

@_transparent
@Sendable public func future<Value>(
	of _: Value.Type = Value.self,
	_ operation: (consuming Promise<Value>) -> Void
) async throws -> Value
where Value: Sendable {
	let promise: Promise<Value> = .init()
	return try await withTaskCancellationHandler(
		operation: {
			try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Value, Error>) in
				if promise.prepared(with: continuation) {
					operation(promise)
				}
				else {
					// noop - already cancelled
				}
			}
		},
		onCancel: promise.cancel
	)
}
