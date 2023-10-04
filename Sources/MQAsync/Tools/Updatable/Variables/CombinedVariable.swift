import struct Atomics.UnsafeAtomic

extension Updatable {

	public func combined<Other, Combined>(
		with other: any Updatable<Other>,
		combine: @escaping @Sendable (MomentaryState<Value>, MomentaryState<Other>) throws -> Combined
	) -> some Updatable<Combined>
	where Other: Sendable, Combined: Sendable {
		CombinedVariable(
			from: self,
			and: other,
			combine: combine
		)
	}
}

public final class CombinedVariable<Value, SourceAValue, SourceBValue>: @unchecked Sendable
where Value: Sendable, SourceAValue: Sendable, SourceBValue: Sendable {

	@usableFromInline internal typealias UpdateTask = Task<MomentaryState<Value>, Error>
	@usableFromInline internal let lock: UnsafeLock
	@usableFromInline internal var current: MomentaryState<Value>
	@usableFromInline internal var runningUpdate: UpdateTask?
	@usableFromInline internal let sourceA: any Updatable<SourceAValue>
	@usableFromInline internal let sourceB: any Updatable<SourceBValue>
	@usableFromInline internal let combine:
		@Sendable (MomentaryState<SourceAValue>, MomentaryState<SourceBValue>) throws -> Value

	public init(
		from sourceA: any Updatable<SourceAValue>,
		and sourceB: any Updatable<SourceBValue>,
		combine: @escaping @Sendable (MomentaryState<SourceAValue>, MomentaryState<SourceBValue>) throws -> Value
	) {
		self.lock = .unsafe_init()
		self.current = .uninitialized
		self.runningUpdate = .none
		self.sourceA = sourceA
		self.sourceB = sourceB
		self.combine = combine
	}

	deinit {
		self.runningUpdate?.cancel()
		self.lock.unsafe_deinit()
	}
}

extension CombinedVariable: Updatable {

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
				let task: UpdateTask = .detached { [sourceA, sourceB, combine, tryUpdate] in
					var sourceAState: MomentaryState<SourceAValue>
					var sourceBState: MomentaryState<SourceBValue>
					var combinedState: MomentaryState<Value>
					repeat {
						sourceAState = try await sourceA.state
						sourceBState = try await sourceB.state
						combinedState = .init(
							generation: Swift.max(
								sourceAState.generation,
								sourceBState.generation
							)
						) {
							try combine(sourceAState, sourceBState)
						}
					} while !tryUpdate(combinedState)
					return combinedState
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

extension CombinedVariable {

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
