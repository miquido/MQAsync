@frozen public enum MomentaryState<Value>: Sendable
where Value: Sendable {

	case value(Value, generation: StateGeneration)
	case issue(Error, generation: StateGeneration)
}

extension MomentaryState {

	public var value: Value {
		@_transparent get throws {
			switch self {
			case .value(let value, _):
				return value

			case .issue(let error, _):
				throw error
			}
		}
	}

	public var generation: StateGeneration {
		@_transparent _read {
			switch self {
			case .value(_, let generation), .issue(_, let generation):
				yield generation
			}
		}
	}

	@_transparent @usableFromInline internal init(
		generation: @autoclosure () -> StateGeneration = .next(),
		_ resolve: () throws -> Value
	) {
		do {
			self = try .value(resolve(), generation: generation())
		}
		catch {
			self = .issue(error, generation: generation())
		}
	}

	@_transparent @usableFromInline internal init(
		generation: @autoclosure () -> StateGeneration = .next(),
		_ resolve: () async throws -> Value
	) async {
		do {
			self = try await .value(resolve(), generation: generation())
		}
		catch {
			self = .issue(error, generation: generation())
		}
	}
}

extension MomentaryState {

	public static var uninitialized: Self {
		.issue(
			Uninitialized.error(),
			generation: .uninitialized
		)
	}
}
