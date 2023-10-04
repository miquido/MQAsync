import struct Atomics.UnsafeAtomic

public final class Variable<Value>: @unchecked Sendable
where Value: Sendable {

	@usableFromInline internal let lock: UnsafeLock
	@usableFromInline internal let atomicGeneration: AtomicStateGeneration
	@usableFromInline internal var current: Value
	@usableFromInline internal var waitingForUpdates: PromiseList<Void>?

	public init(
		_ initial: consuming Value
	) {
		self.lock = .unsafe_init()
		self.atomicGeneration = .create(.next())
		self.current = initial
		self.waitingForUpdates = .none
	}

	deinit {
		self.lock.unsafe_deinit()
		self.atomicGeneration.destroy()
		self.waitingForUpdates?.cancel()
	}
}

extension Variable: Updatable {

	public var generation: StateGeneration {
		@_transparent @Sendable _read {
			yield self.atomicGeneration.current()
		}
	}

	public var value: Value {
		@_transparent @Sendable _read {
			self.lock.unsafe_lock()
			yield self.current
			self.lock.unsafe_unlock()
		}
		@_transparent @Sendable _modify {
			self.lock.unsafe_lock()
			yield &self.current
			self.atomicGeneration.update()
			let waitingToNotify: PromiseList? = self.waitingForUpdates.take()
			self.lock.unsafe_unlock()
			waitingToNotify?.fulfill(with: Void())
		}
	}

	public var state: MomentaryState<Value> {
		@_transparent @Sendable _read {
			self.lock.unsafe_lock()
			let value: Value = self.current
			let generation: StateGeneration = self.atomicGeneration.current()
			self.lock.unsafe_unlock()
			// make allocation outside of lock
			yield .value(
				value,
				generation: generation
			)
		}
	}

	public func notifyOnUpdate(
		_ promise: Promise<Void>,
		from generation: StateGeneration
	) {
		self.lock.unsafe_lock()
		if self.atomicGeneration.current() > generation {
			self.lock.unsafe_unlock()
			promise.fulfill()
		}
		else {
			self.waitingForUpdates.linkOrSet(promise)
			self.lock.unsafe_unlock()
		}
	}
}

extension Variable {

	@discardableResult
	@inlinable @Sendable public func mutate<Returned>(
		@_implicitSelfCapture _ mutation: (inout Value) -> Returned
	) -> Returned {
		mutation(&self.value)
	}
}
