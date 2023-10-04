extension Optional {

	@_transparent @usableFromInline internal mutating func take() -> Wrapped? {
		switch self {
		case .some(let wrapped):
			self = .none
			return .some(wrapped)

		case .none:
			return self
		}
	}
}
