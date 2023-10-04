public final class Constant<Value>: @unchecked Sendable
where Value: Sendable {

	public static var uninitialized: Self { .init() }

	public let state: MomentaryState<Value>

	public init(
		_ value: consuming Value
	) {
		self.state = .value(
			value,
			generation: .next()
		)
	}

	public init(
		_ issue: consuming Error
	) {
		self.state = .issue(
			issue,
			generation: .next()
		)
	}

	private init() {
		self.state = .uninitialized
	}
}

extension Constant: Updatable {

	public var generation: StateGeneration {
		@_transparent @Sendable _read {
			yield self.state.generation
		}
	}

	public var value: Value {
		@_transparent @Sendable get throws {
			try self.state.value
		}
	}

	public func notifyOnUpdate(
		_ promise: Promise<Void>,
		from generation: StateGeneration
	) {
		// never notify
	}
}
