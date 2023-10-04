public final class AnyUpdatable<Value>
where Value: Sendable {

	@usableFromInline internal let source: any Updatable<Value>

	@usableFromInline internal init<Source>(
		erasing source: Source
	) where Source: Updatable, Source.Value == Value {
		self.source = source
	}
}

extension Updatable {

	@inlinable public func asAnyUpdatable() -> AnyUpdatable<Value> {
		self as? AnyUpdatable<Value> ?? AnyUpdatable<Value>(erasing: self)
	}
}

extension AnyUpdatable: Updatable {

	public var generation: StateGeneration {
		@_transparent @Sendable _read {
			yield self.source.generation
		}
	}

	public var state: MomentaryState<Value> {
		@_transparent get async throws {
			try await self.source.state
		}
	}

	@_transparent @Sendable public func notifyOnUpdate(
		_ promise: Promise<Void>,
		from generation: StateGeneration
	) {
		self.source.notifyOnUpdate(promise, from: generation)
	}
}
