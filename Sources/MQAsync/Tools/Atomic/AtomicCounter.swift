import class Atomics.ManagedAtomic

public struct AtomicCounter {

	private let atomic: ManagedAtomic<Int>

	public init(
		initial: Int = 0
	) {
		self.atomic = .init(initial)
	}

	public var value: Int {
		_read { yield self.atomic.load(ordering: .relaxed) }
	}

	public func increment() {
		self.atomic.wrappingIncrement(ordering: .relaxed)
	}

	public func decrement() {
		self.atomic.wrappingDecrement(ordering: .relaxed)
	}
}
