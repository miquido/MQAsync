import class Atomics.ManagedAtomic

public struct AtomicFlag {

	private let atomic: ManagedAtomic<Bool>

	public init() {
		self.atomic = .init(false)
	}

	public var value: Bool {
		_read { yield self.atomic.load(ordering: .relaxed) }
	}

	public func set() {
		self.atomic.store(true, ordering: .relaxed)
	}

	public func clear() {
		self.atomic.store(false, ordering: .relaxed)
	}
}
