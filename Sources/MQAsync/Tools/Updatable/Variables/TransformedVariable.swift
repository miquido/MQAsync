import struct Atomics.UnsafeAtomic

extension Updatable {

	public func transformed<Transformed>(
		_ transform: @escaping @Sendable (MomentaryState<Value>) async throws -> Transformed
	) -> some Updatable<Transformed>
	where Transformed: Sendable {
		TransformedVariable(
			from: self,
			transform: transform
		)
	}
}

public final class TransformedVariable<Value, SourceValue>: @unchecked Sendable
where Value: Sendable, SourceValue: Sendable {

	@usableFromInline internal typealias UpdateTask = Task<MomentaryState<Value>, Error>
	@usableFromInline internal let lock: UnsafeLock
	@usableFromInline internal var current: MomentaryState<Value>
	@usableFromInline internal var runningUpdate: UpdateTask?
	@usableFromInline internal let source: any Updatable<SourceValue>
	@usableFromInline internal let transform: @Sendable (MomentaryState<SourceValue>) async throws -> Value

	public init(
		from source: any Updatable<SourceValue>,
		transform: @escaping @Sendable (MomentaryState<SourceValue>) async throws -> Value
	) {
		self.lock = .unsafe_init()
		self.current = .uninitialized
		self.runningUpdate = .none
		self.source = source
		self.transform = transform
	}

	deinit {
		self.runningUpdate?.cancel()
		self.lock.unsafe_deinit()
	}
}

extension TransformedVariable: Updatable {

	public var generation: StateGeneration {
		@_transparent @Sendable _read {
			yield self.source.generation
		}
	}

	public var state: MomentaryState<Value> {
		@Sendable get async throws {
			self.lock.unsafe_lock()
			if self.current.generation == self.source.generation {
				defer { self.lock.unsafe_unlock() }
				return self.current
			}
			else if let task: UpdateTask = self.runningUpdate {
				self.lock.unsafe_unlock()
				return try await task.value
			}
			else {
				let task: UpdateTask = .detached { [source, transform, tryUpdate] in
					var sourceState: MomentaryState<SourceValue>
					var transformedState: MomentaryState<Value>
					repeat {
						sourceState = try await source.state
						transformedState = await .init(
							generation: sourceState.generation
						) {
							try await transform(sourceState)
						}
					} while !tryUpdate(transformedState)
					return transformedState
				}
				self.runningUpdate = task
				self.lock.unsafe_unlock()
				return try await task.value
			}
		}
	}

	@Sendable public func notifyOnUpdate(
		_ promise: Promise<Void>,
		from generation: StateGeneration
	) {
		self.source.notifyOnUpdate(promise, from: generation)
	}
}

extension TransformedVariable {

	@usableFromInline @Sendable internal func tryUpdate(
		from state: MomentaryState<Value>
	) -> Bool {
		self.lock.unsafe_lock()
		if state.generation == self.generation {
			assert(self.runningUpdate?.isCurrent ?? false)
			assert(self.current.generation < state.generation)
			self.current = state
			self.runningUpdate = .none
			self.lock.unsafe_unlock()
			return true
		}
		else {
			self.lock.unsafe_unlock()
			return false
		}
	}
}
