import struct Atomics.UnsafeAtomic

extension Updatable {

	public func merged(
		with other: any Updatable<Value>
	) -> some Updatable<Value> {
		MergedVariable(
			from: self,
			and: other
		)
	}
}

public final class MergedVariable<Value>: @unchecked Sendable
where Value: Sendable {

	@usableFromInline internal typealias UpdateTask = Task<MomentaryState<Value>, Error>
	@usableFromInline internal let lock: UnsafeLock
	@usableFromInline internal var current: MomentaryState<Value>
	@usableFromInline internal var runningUpdate: UpdateTask?
	@usableFromInline internal let sourceA: any Updatable<Value>
	@usableFromInline internal let sourceB: any Updatable<Value>

	public init(
		from sourceA: any Updatable<Value>,
		and sourceB: any Updatable<Value>
	) {
		self.lock = .unsafe_init()
		self.current = .uninitialized
		self.runningUpdate = .none
		self.sourceA = sourceA
		self.sourceB = sourceB
	}

	deinit {
		self.runningUpdate?.cancel()
		self.lock.unsafe_deinit()
	}
}

extension MergedVariable: Updatable {

	public var generation: StateGeneration {
		@_transparent @Sendable _read {
			yield Swift.max(
				self.sourceA.generation,
				self.sourceB.generation
			)
		}
	}

	public var state: MomentaryState<Value> {
		@Sendable get async throws {
			self.lock.unsafe_lock()
			if self.current.generation == self.generation {
				defer { self.lock.unsafe_unlock() }
				return self.current
			}
			else if let task: UpdateTask = self.runningUpdate {
				self.lock.unsafe_unlock()
				return try await task.value
			}
			else {
				let task: UpdateTask = .detached { [sourceA, sourceB, tryUpdate] in
					var sourceState: MomentaryState<Value>
					repeat {
						if sourceA.generation > sourceB.generation {
							sourceState = try await sourceA.state
						}
						else {
							sourceState = try await sourceB.state
						}
					} while !tryUpdate(sourceState)
					return sourceState
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
		// race - whoever notifies first will win
		if sourceA.generation > sourceB.generation {
			self.sourceA.notifyOnUpdate(promise, from: generation)
			self.sourceB.notifyOnUpdate(promise, from: generation)
		}
		else {
			self.sourceB.notifyOnUpdate(promise, from: generation)
			self.sourceA.notifyOnUpdate(promise, from: generation)
		}
	}
}

extension MergedVariable {

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
