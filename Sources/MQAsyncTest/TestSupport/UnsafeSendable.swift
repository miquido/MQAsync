public final class UnsafeSendable<Value>: @unchecked Sendable {

	private let pointer: UnsafeMutablePointer<Value?>

	public init() {
		self.pointer = .allocate(capacity: 1)
		self.pointer.initialize(repeating: .none, count: 1)
	}

	deinit {
		self.pointer.deallocate()
	}

	@Sendable public func set(
		_ value: Value?
	) {
		self.pointer.pointee = value
	}

	public var value: Value? {
		get { self.pointer.pointee }
		set { self.pointer.pointee = newValue }
	}

	public var unwrappedValue: Value {
		get { self.pointer.pointee! }
		set { self.pointer.pointee = newValue }
	}
}
