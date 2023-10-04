public protocol Updatable<Value>: AnyObject, Sendable, AsyncSequence {

	associatedtype Value: Sendable

	nonisolated var generation: StateGeneration { @Sendable get }
	var value: Value { @Sendable get async throws }
	var state: MomentaryState<Value> { @Sendable get async throws }

	@Sendable func notifyOnUpdate(
		_ promise: Promise<Void>,
		from generation: StateGeneration
	)
}

extension Updatable {

	public var value: Value {
		@_transparent @Sendable get async throws {
			try await self.state.value
		}
	}

	@_transparent @Sendable public func notifyOnUpdate(
		_ promise: Promise<Void>
	) {
		self.notifyOnUpdate(
			promise,
			from: self.generation
		)
	}

	@_transparent @Sendable public func waitForUpdate(
		from generation: StateGeneration
	) async throws {
		try await future { (promise: Promise<Void>) in
			self.notifyOnUpdate(promise, from: generation)
		}
	}

	@_transparent @Sendable public func waitForUpdate() async throws {
		try await future(self.notifyOnUpdate(_:))
	}
}

extension Updatable {

	// despite the warning Swift 5.8 can't use type constraints properly
	// and it does not compile without typealiases
	public typealias Element = MomentaryState<Value>
	public typealias AsyncIterator = UpdatableIterator<Value>

	@Sendable public func makeAsyncIterator() -> UpdatableIterator<Value> {
		UpdatableIterator<Value>(source: self)
	}
}
